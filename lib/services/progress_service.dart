import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 內容進度狀態（SSOT：Firestore）
enum ProgressState {
  queued,      // 已加入排程候選
  scheduled,   // 已排程（通知已註冊）
  delivered,   // 已送達（iOS/Android 確認）
  opened,      // 已開啟（用戶點擊）
  learned,     // 已學會（用戶標記完成）
  snoozed,     // 延後再學
  dismissed,   // 用戶滑掉
  expired,     // 過期未處理（5分鐘後）
}

/// 本地行動佇列項目（待同步到 Firestore）
class LocalAction {
  final String id; // uuid
  final String contentId;
  final String action; // learned/snooze/opened/dismissed
  final int atMs;
  final Map<String, dynamic> payload;
  final bool synced;

  LocalAction({
    required this.id,
    required this.contentId,
    required this.action,
    required this.atMs,
    this.payload = const {},
    this.synced = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'contentId': contentId,
        'action': action,
        'atMs': atMs,
        'payload': payload,
        'synced': synced,
      };

  static LocalAction fromJson(Map<String, dynamic> json) => LocalAction(
        id: json['id'] as String,
        contentId: json['contentId'] as String,
        action: json['action'] as String,
        atMs: (json['atMs'] as num).toInt(),
        payload: json['payload'] as Map<String, dynamic>? ?? {},
        synced: json['synced'] as bool? ?? false,
      );
}

/// 合併後的進度狀態（Firestore + Local Queue）
class MergedProgress {
  final String contentId;
  final String topicId;
  final String productId;
  final ProgressState state;
  final int? pushOrder;
  final DateTime? scheduledFor;
  final DateTime? snoozedUntil;
  final DateTime? openedAt;
  final DateTime? learnedAt;
  final DateTime? dismissedAt;
  final DateTime? expiredAt;

  const MergedProgress({
    required this.contentId,
    required this.topicId,
    required this.productId,
    required this.state,
    this.pushOrder,
    this.scheduledFor,
    this.snoozedUntil,
    this.openedAt,
    this.learnedAt,
    this.dismissedAt,
    this.expiredAt,
  });

  /// 是否應該排除（不再排程）
  bool get shouldExclude =>
      state == ProgressState.learned ||
      state == ProgressState.dismissed ||
      state == ProgressState.expired ||
      (state == ProgressState.snoozed &&
          snoozedUntil != null &&
          DateTime.now().isBefore(snoozedUntil!));
}

/// 統一的進度服務（SSOT + Queue 架構）
/// 
/// 架構原則：
/// 1. Firestore 是唯一真相來源（SSOT）
/// 2. SharedPreferences 只做 cache/queue（待同步事件）
/// 3. 所有寫入必須通過此服務
/// 4. UI 顯示與排程基於：Firestore + local queue 合併後的狀態
class ProgressService {
  final FirebaseFirestore _db;
  static const String _queueKey = 'local_action_queue_v1';

  ProgressService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Firestore 路徑：users/{uid}/progress/{contentId}
  DocumentReference<Map<String, dynamic>> _progressRef(
      String uid, String contentId) {
    return _db.collection('users').doc(uid).collection('progress').doc(contentId);
  }

  // ========== Local Action Queue ==========

  /// 讀取本地行動佇列
  Future<List<LocalAction>> _loadQueue() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_queueKey);
      if (raw == null || raw.isEmpty) return [];

      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => LocalAction.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ _loadQueue error: $e');
      }
      return [];
    }
  }

  /// 儲存本地行動佇列
  Future<void> _saveQueue(List<LocalAction> queue) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final list = queue.map((e) => e.toJson()).toList();
      await sp.setString(_queueKey, jsonEncode(list));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ _saveQueue error: $e');
      }
    }
  }

  /// 加入本地佇列（立即生效，稍後同步）
  Future<void> _enqueue(LocalAction action) async {
    final queue = await _loadQueue();
    queue.add(action);
    await _saveQueue(queue);

    if (kDebugMode) {
      debugPrint(
          '📋 已加入本地佇列：action=${action.action}, contentId=${action.contentId}');
    }

    // 背景同步（不等待）
    _syncQueue().ignore();
  }

  /// 同步佇列到 Firestore（背景執行）
  Future<void> _syncQueue() async {
    try {
      final queue = await _loadQueue();
      if (queue.isEmpty) return;

      final unsynced = queue.where((e) => !e.synced).toList();
      if (unsynced.isEmpty) return;

      if (kDebugMode) {
        debugPrint('🔄 開始同步 ${unsynced.length} 個本地行動到 Firestore...');
      }

      final newQueue = <LocalAction>[];
      for (final action in queue) {
        if (action.synced) {
          newQueue.add(action);
          continue;
        }

        try {
          // 嘗試同步到 Firestore
          await _syncActionToFirestore(action);

          // 標記為已同步
          newQueue.add(LocalAction(
            id: action.id,
            contentId: action.contentId,
            action: action.action,
            atMs: action.atMs,
            payload: action.payload,
            synced: true,
          ));

          if (kDebugMode) {
            debugPrint(
                '✅ 已同步：action=${action.action}, contentId=${action.contentId}');
          }
        } catch (e) {
          // 同步失敗，保留在佇列中待下次重試
          newQueue.add(action);
          if (kDebugMode) {
            debugPrint(
                '❌ 同步失敗，保留在佇列：action=${action.action}, contentId=${action.contentId}, error=$e');
          }
        }
      }

      // 清理已同步超過 7 天的記錄
      final now = DateTime.now().millisecondsSinceEpoch;
      final sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
      final cleaned = newQueue
          .where((e) => !e.synced || (now - e.atMs) < sevenDaysMs)
          .toList();

      await _saveQueue(cleaned);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ _syncQueue error: $e');
      }
    }
  }

  /// 將單個 action 同步到 Firestore
  Future<void> _syncActionToFirestore(LocalAction action) async {
    final uid = action.payload['uid'] as String?;
    final topicId = action.payload['topicId'] as String?;
    final productId = action.payload['productId'] as String?;
    final pushOrder = action.payload['pushOrder'] as int?;

    if (uid == null || topicId == null || productId == null) {
      throw ArgumentError('Missing required fields in payload');
    }

    final ref = _progressRef(uid, action.contentId);
    final now = Timestamp.fromMillisecondsSinceEpoch(action.atMs);

    switch (action.action) {
      case 'learned':
        await ref.set({
          'contentId': action.contentId,
          'topicId': topicId,
          'productId': productId,
          'state': ProgressState.learned.name,
          if (pushOrder != null) 'pushOrder': pushOrder,
          'learnedAt': now,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        break;

      case 'snooze':
        final snoozedUntilMs = action.payload['snoozedUntilMs'] as int?;
        await ref.set({
          'contentId': action.contentId,
          'topicId': topicId,
          'productId': productId,
          'state': ProgressState.snoozed.name,
          if (pushOrder != null) 'pushOrder': pushOrder,
          if (snoozedUntilMs != null)
            'snoozedUntil': Timestamp.fromMillisecondsSinceEpoch(snoozedUntilMs),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        break;

      case 'opened':
        await ref.set({
          'contentId': action.contentId,
          'topicId': topicId,
          'productId': productId,
          'state': ProgressState.opened.name,
          if (pushOrder != null) 'pushOrder': pushOrder,
          'openedAt': now,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        break;

      case 'dismissed':
        await ref.set({
          'contentId': action.contentId,
          'topicId': topicId,
          'productId': productId,
          'state': ProgressState.dismissed.name,
          if (pushOrder != null) 'pushOrder': pushOrder,
          'dismissedAt': now,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        break;
    }
  }

  // ========== 公開 API：所有狀態變更入口 ==========

  /// 標記為已學會
  /// 1. 立即寫入本地 queue
  /// 2. 背景同步到 Firestore
  Future<void> markLearned({
    required String uid,
    required String contentId,
    required String topicId,
    required String productId,
    int? pushOrder,
  }) async {
    final action = LocalAction(
      id: '${DateTime.now().millisecondsSinceEpoch}_${contentId}_learned',
      contentId: contentId,
      action: 'learned',
      atMs: DateTime.now().millisecondsSinceEpoch,
      payload: {
        'uid': uid,
        'topicId': topicId,
        'productId': productId,
        if (pushOrder != null) 'pushOrder': pushOrder,
      },
    );

    await _enqueue(action);
  }

  /// 延後再學
  Future<void> markSnoozed({
    required String uid,
    required String contentId,
    required String topicId,
    required String productId,
    required DateTime snoozedUntil,
    int? pushOrder,
  }) async {
    final action = LocalAction(
      id: '${DateTime.now().millisecondsSinceEpoch}_${contentId}_snooze',
      contentId: contentId,
      action: 'snooze',
      atMs: DateTime.now().millisecondsSinceEpoch,
      payload: {
        'uid': uid,
        'topicId': topicId,
        'productId': productId,
        'snoozedUntilMs': snoozedUntil.millisecondsSinceEpoch,
        if (pushOrder != null) 'pushOrder': pushOrder,
      },
    );

    await _enqueue(action);
  }

  /// 標記為已開啟
  Future<void> markOpened({
    required String uid,
    required String contentId,
    required String topicId,
    required String productId,
    int? pushOrder,
  }) async {
    final action = LocalAction(
      id: '${DateTime.now().millisecondsSinceEpoch}_${contentId}_opened',
      contentId: contentId,
      action: 'opened',
      atMs: DateTime.now().millisecondsSinceEpoch,
      payload: {
        'uid': uid,
        'topicId': topicId,
        'productId': productId,
        if (pushOrder != null) 'pushOrder': pushOrder,
      },
    );

    await _enqueue(action);
  }

  /// 標記為滑掉
  Future<void> markDismissed({
    required String uid,
    required String contentId,
    required String topicId,
    required String productId,
    int? pushOrder,
  }) async {
    final action = LocalAction(
      id: '${DateTime.now().millisecondsSinceEpoch}_${contentId}_dismissed',
      contentId: contentId,
      action: 'dismissed',
      atMs: DateTime.now().millisecondsSinceEpoch,
      payload: {
        'uid': uid,
        'topicId': topicId,
        'productId': productId,
        if (pushOrder != null) 'pushOrder': pushOrder,
      },
    );

    await _enqueue(action);
  }

  // ========== 合併狀態查詢 ==========

  /// 獲取合併後的進度（Firestore + Local Queue）
  /// 
  /// 優先順序：
  /// 1. Local queue 中未同步的 action（最新）
  /// 2. Firestore 中的狀態（已同步）
  Future<MergedProgress?> getMergedProgress({
    required String uid,
    required String contentId,
  }) async {
    // 1. 讀取本地佇列
    final queue = await _loadQueue();
    final localActions = queue
        .where((e) => e.contentId == contentId && !e.synced)
        .toList()
      ..sort((a, b) => b.atMs.compareTo(a.atMs)); // 最新的在前

    // 2. 讀取 Firestore
    MergedProgress? fromFirestore;
    try {
      final doc = await _progressRef(uid, contentId).get();
      if (doc.exists) {
        final data = doc.data()!;
        fromFirestore = _parseFirestoreProgress(contentId, data);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ 讀取 Firestore progress 失敗：$e');
      }
    }

    // 3. 合併：local queue 優先
    if (localActions.isNotEmpty) {
      final latest = localActions.first;
      final topicId = latest.payload['topicId'] as String? ?? '';
      final productId = latest.payload['productId'] as String? ?? '';
      final pushOrder = latest.payload['pushOrder'] as int?;

      ProgressState state;
      DateTime? snoozedUntil;
      DateTime? openedAt;
      DateTime? learnedAt;
      DateTime? dismissedAt;

      switch (latest.action) {
        case 'learned':
          state = ProgressState.learned;
          learnedAt = DateTime.fromMillisecondsSinceEpoch(latest.atMs);
          break;
        case 'snooze':
          state = ProgressState.snoozed;
          final ms = latest.payload['snoozedUntilMs'] as int?;
          if (ms != null) {
            snoozedUntil = DateTime.fromMillisecondsSinceEpoch(ms);
          }
          break;
        case 'opened':
          state = ProgressState.opened;
          openedAt = DateTime.fromMillisecondsSinceEpoch(latest.atMs);
          break;
        case 'dismissed':
          state = ProgressState.dismissed;
          dismissedAt = DateTime.fromMillisecondsSinceEpoch(latest.atMs);
          break;
        default:
          state = ProgressState.queued;
      }

      return MergedProgress(
        contentId: contentId,
        topicId: topicId,
        productId: productId,
        state: state,
        pushOrder: pushOrder,
        snoozedUntil: snoozedUntil,
        openedAt: openedAt,
        learnedAt: learnedAt,
        dismissedAt: dismissedAt,
        scheduledFor: fromFirestore?.scheduledFor,
      );
    }

    // 4. 沒有本地 action，使用 Firestore 狀態
    return fromFirestore;
  }

  /// 批量獲取合併後的進度（用於排程）
  Future<Map<String, MergedProgress>> getMergedProgressBatch({
    required String uid,
    required List<String> contentIds,
  }) async {
    final result = <String, MergedProgress>{};

    // 1. 讀取本地佇列（一次性）
    final queue = await _loadQueue();
    final queueByContent = <String, List<LocalAction>>{};
    for (final action in queue.where((e) => !e.synced)) {
      queueByContent.putIfAbsent(action.contentId, () => []).add(action);
    }

    // 2. 批量讀取 Firestore（效能優化）
    try {
      final refs = contentIds.map((id) => _progressRef(uid, id)).toList();
      final docs = await Future.wait(refs.map((ref) => ref.get()));

      for (int i = 0; i < contentIds.length; i++) {
        final contentId = contentIds[i];
        final doc = docs[i];

        MergedProgress? fromFirestore;
        if (doc.exists) {
          fromFirestore = _parseFirestoreProgress(contentId, doc.data()!);
        }

        // 合併本地 queue
        final localActions = queueByContent[contentId];
        if (localActions != null && localActions.isNotEmpty) {
          localActions.sort((a, b) => b.atMs.compareTo(a.atMs));
          final latest = localActions.first;

          result[contentId] = _mergeWithLocalAction(
            contentId: contentId,
            localAction: latest,
            firestoreProgress: fromFirestore,
          );
        } else if (fromFirestore != null) {
          result[contentId] = fromFirestore;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ getMergedProgressBatch error: $e');
      }
    }

    return result;
  }

  /// 解析 Firestore 進度文檔
  MergedProgress _parseFirestoreProgress(
      String contentId, Map<String, dynamic> data) {
    final stateStr = data['state'] as String? ?? 'queued';
    final state = ProgressState.values.firstWhere(
      (e) => e.name == stateStr,
      orElse: () => ProgressState.queued,
    );

    DateTime? parseTimestamp(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    return MergedProgress(
      contentId: contentId,
      topicId: data['topicId'] as String? ?? '',
      productId: data['productId'] as String? ?? '',
      state: state,
      pushOrder: data['pushOrder'] as int?,
      scheduledFor: parseTimestamp(data['scheduledFor']),
      snoozedUntil: parseTimestamp(data['snoozedUntil']),
      openedAt: parseTimestamp(data['openedAt']),
      learnedAt: parseTimestamp(data['learnedAt']),
      dismissedAt: parseTimestamp(data['dismissedAt']),
      expiredAt: parseTimestamp(data['expiredAt']),
    );
  }

  /// 合併本地 action 與 Firestore 狀態
  MergedProgress _mergeWithLocalAction({
    required String contentId,
    required LocalAction localAction,
    MergedProgress? firestoreProgress,
  }) {
    final topicId = localAction.payload['topicId'] as String? ?? '';
    final productId = localAction.payload['productId'] as String? ?? '';
    final pushOrder = localAction.payload['pushOrder'] as int?;

    ProgressState state;
    DateTime? snoozedUntil;
    DateTime? openedAt;
    DateTime? learnedAt;
    DateTime? dismissedAt;

    switch (localAction.action) {
      case 'learned':
        state = ProgressState.learned;
        learnedAt = DateTime.fromMillisecondsSinceEpoch(localAction.atMs);
        break;
      case 'snooze':
        state = ProgressState.snoozed;
        final ms = localAction.payload['snoozedUntilMs'] as int?;
        if (ms != null) {
          snoozedUntil = DateTime.fromMillisecondsSinceEpoch(ms);
        }
        break;
      case 'opened':
        state = ProgressState.opened;
        openedAt = DateTime.fromMillisecondsSinceEpoch(localAction.atMs);
        break;
      case 'dismissed':
        state = ProgressState.dismissed;
        dismissedAt = DateTime.fromMillisecondsSinceEpoch(localAction.atMs);
        break;
      default:
        state = ProgressState.queued;
    }

    return MergedProgress(
      contentId: contentId,
      topicId: topicId,
      productId: productId,
      state: state,
      pushOrder: pushOrder,
      snoozedUntil: snoozedUntil,
      openedAt: openedAt,
      learnedAt: learnedAt,
      dismissedAt: dismissedAt,
      scheduledFor: firestoreProgress?.scheduledFor,
    );
  }

  /// 強制同步（由 UI 觸發）
  Future<void> forceSyncNow() async {
    await _syncQueue();
  }

  /// 清空本地佇列（測試/重置用）
  Future<void> clearQueue() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_queueKey);
  }
}
