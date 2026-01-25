import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 收件匣項目狀態
enum InboxStatus {
  scheduled, // 已排程（未來）
  missed,    // 錯過（已過期但未開啟）
  opened,    // 已開啟
  skipped,   // 已跳過
}

/// 收件匣項目
class InboxItem {
  final String productId;
  final String contentItemId;
  final int whenMs; // 排程時間（毫秒）
  final String title;
  final String body;
  final InboxStatus status;

  InboxItem({
    required this.productId,
    required this.contentItemId,
    required this.whenMs,
    required this.title,
    required this.body,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'contentItemId': contentItemId,
        'whenMs': whenMs,
        'title': title,
        'body': body,
        'status': status.name,
      };

  static InboxItem fromJson(Map<String, dynamic> j) => InboxItem(
        productId: j['productId']?.toString() ?? '',
        contentItemId: j['contentItemId']?.toString() ?? '',
        whenMs: (j['whenMs'] as num?)?.toInt() ?? 0,
        title: j['title']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        status: _parseStatus(j['status']?.toString()),
      );

  static InboxStatus _parseStatus(String? s) {
    switch (s) {
      case 'scheduled':
        return InboxStatus.scheduled;
      case 'missed':
        return InboxStatus.missed;
      case 'opened':
        return InboxStatus.opened;
      case 'skipped':
        return InboxStatus.skipped;
      default:
        return InboxStatus.missed;
    }
  }
}

/// 通知收件匣：已讀(Opened) 本機紀錄
///
/// - 全域 opened（不分商品）：key = inbox_opened_<uid>
/// - 商品 scoped opened：key = inbox_opened_<uid>_<productId>
/// - 排程項目：key = inbox_scheduled_<uid>
/// - 錯過項目：key = inbox_missed_<uid>
///
/// value: {"<contentItemId>": <openedAtMs>, ...}
class NotificationInboxStore {
  static String _kGlobal(String uid) => 'inbox_opened_$uid';
  static String _kScoped(String uid, String productId) =>
      'inbox_opened_${uid}_$productId';

  static Future<Map<String, int>> _loadMap(String key) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveMap(String key, Map<String, int> map) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(key, jsonEncode(map));
  }

  /// 讀：全域 opened map
  static Future<Map<String, int>> loadOpenedGlobal(String uid) async {
    return _loadMap(_kGlobal(uid));
  }

  /// 讀：商品 scoped opened map
  static Future<Map<String, int>> loadOpenedForProduct(
      String uid, String productId) async {
    if (productId.isEmpty) return {};
    return _loadMap(_kScoped(uid, productId));
  }

  /// 寫：標記 opened（同時寫入全域 + scoped）
  static Future<void> markOpened(
    String uid, {
    required String productId,
    required String contentItemId,
  }) async {
    if (uid.isEmpty || contentItemId.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    // 1) global
    final kg = _kGlobal(uid);
    final g = await _loadMap(kg);
    g[contentItemId] = now;
    await _saveMap(kg, g);

    // 2) scoped
    if (productId.isNotEmpty) {
      final ks = _kScoped(uid, productId);
      final s = await _loadMap(ks);
      s[contentItemId] = now;
      await _saveMap(ks, s);
    }
  }

  static Future<bool> isOpenedGlobal(String uid, String contentItemId) async {
    final g = await loadOpenedGlobal(uid);
    return g.containsKey(contentItemId);
  }

  static Future<bool> isOpenedForProduct(
      String uid, String productId, String contentItemId) async {
    final s = await loadOpenedForProduct(uid, productId);
    return s.containsKey(contentItemId);
  }

  static Future<void> clearAll(String uid) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kGlobal(uid));
    // scoped keys 不好枚舉；如果你需要「清除全部(含所有商品)」，
    // 我可以幫你加一個 key registry 來追蹤所有 productId。
  }

  static Future<void> clearForProduct(String uid, String productId) async {
    if (productId.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kScoped(uid, productId));
  }

  /// 立即標記為錯過（適用於「滑掉」通知的情境）
  /// 會嘗試將 scheduled 內對應項目移到 missed，並保留原本的 title/body/whenMs
  /// 注意：此方法會立即標記為錯失，不等待 5 分鐘過期時間
  /// 
  /// 狀態優先順序：opened > missed
  /// - 如果已開啟，則不標記為 missed
  /// - 使用 contentItemId 作為唯一鍵進行判斷和去重
  static Future<void> markMissedByContentItemId(
    String uid, {
    required String productId,
    required String contentItemId,
  }) async {
    if (uid.isEmpty || productId.isEmpty || contentItemId.isEmpty) return;

    // ✅ opened 優先：如果已開啟，則不標記為 missed
    final opened = await loadOpenedGlobal(uid);
    if (opened.containsKey(contentItemId)) {
      if (kDebugMode) {
        debugPrint('ℹ️ markMissedByContentItemId: contentItemId=$contentItemId 已開啟，不標記為 missed');
      }
      return;
    }

    final scheduledKey = _kScheduled(uid);
    final missedKey = _kMissed(uid);

    final scheduled = await _loadItems(scheduledKey);
    final missed = await _loadItems(missedKey);

    // ✅ 使用 contentItemId 判斷是否已在 missed 列表
    final alreadyMissed = missed.any(
      (item) => item.contentItemId == contentItemId,
    );

    final moved = <InboxItem>[];
    final newScheduled = <InboxItem>[];
    bool foundInScheduled = false;
    
    for (final item in scheduled) {
      if (item.contentItemId == contentItemId) {
        foundInScheduled = true;
        if (!alreadyMissed) {
          moved.add(InboxItem(
            productId: item.productId,
            contentItemId: item.contentItemId,
            whenMs: item.whenMs,
            title: item.title,
            body: item.body,
            status: InboxStatus.missed,
          ));
        }
      } else {
        newScheduled.add(item);
      }
    }

    // ✅ 若 scheduled 中找不到該項目（例如快取已被清掉/重排過），仍要記為 missed
    // 以便後續重排時可排除該 contentItemId，避免一直重排同一則。
    if (!alreadyMissed && !foundInScheduled) {
      moved.add(InboxItem(
        productId: productId,
        contentItemId: contentItemId,
        whenMs: DateTime.now().millisecondsSinceEpoch,
        title: '',
        body: '',
        status: InboxStatus.missed,
      ));
    }

    if (moved.isNotEmpty) {
      final newMissed = List<InboxItem>.from(missed)..addAll(moved);
      // 只有在 scheduled 有移除時才寫回 scheduled
      if (foundInScheduled) {
        await _saveItems(scheduledKey, newScheduled);
      }
      await _saveItems(missedKey, newMissed);
      
      if (kDebugMode) {
        debugPrint('✅ markMissedByContentItemId: contentItemId=$contentItemId 已標記為 missed');
      }
    }
  }

  // ========== 新增：InboxItem 管理 ==========

  static String _kScheduled(String uid) => 'inbox_scheduled_$uid';
  static String _kMissed(String uid) => 'inbox_missed_$uid';

  /// 錯失通知的判斷標準：過期時間必須超過此值（毫秒）
  static const int _missedExpirationThresholdMs = 5 * 60 * 1000; // 5分鐘

  /// 判斷通知是否已過期（用於錯失判斷）
  /// 返回 true 表示：過期時間 >= 5分鐘 且 未開啟
  /// 所有判斷錯失通知的地方都應該使用此方法，確保標準一致
  static bool _isExpiredForMissed(int whenMs, int nowMs) {
    return whenMs < (nowMs - _missedExpirationThresholdMs);
  }

  /// 載入所有收件匣項目（scheduled + missed + opened）
  /// 注意：會先執行 sweepMissed 確保已過期的記錄被正確保存到 missed 列表
  /// 
  /// 狀態優先順序：opened > missed > scheduled
  /// - 已開啟的內容永遠顯示為 opened
  /// - 未開啟但過期5分鐘以上的顯示為 missed
  /// - 未來的排程顯示為 scheduled
  static Future<List<InboxItem>> load(String uid) async {
    // ✅ 先執行 sweepMissed，確保已過期但未讀的通知被移到 missed 列表
    await sweepMissed(uid);
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final opened = await loadOpenedGlobal(uid);

    // 1) 載入 scheduled
    final scheduled = await _loadItems(_kScheduled(uid));
    
    // 2) 載入 missed
    final missed = await _loadItems(_kMissed(uid));

    // 3) 合併並判斷狀態（使用 contentItemId 作為唯一鍵）
    final all = <String, InboxItem>{};
    
    // ✅ 先加入 missed（優先於 scheduled）
    for (final item in missed) {
      final key = item.contentItemId; // 使用 contentItemId 作為唯一鍵
      
      // opened 優先於 missed：如果已開啟，則跳過 missed 記錄
      if (opened.containsKey(item.contentItemId)) {
        continue;
      }
      
      all[key] = InboxItem(
        productId: item.productId,
        contentItemId: item.contentItemId,
        whenMs: item.whenMs,
        title: item.title,
        body: item.body,
        status: InboxStatus.missed,
      );
    }
    
    // ✅ 再加入 scheduled（如果 contentItemId 已存在則跳過，保持 missed 狀態）
    for (final item in scheduled) {
      final key = item.contentItemId;
      
      if (opened.containsKey(item.contentItemId)) {
        // 已開啟：覆蓋為 opened 狀態
        all[key] = InboxItem(
          productId: item.productId,
          contentItemId: item.contentItemId,
          whenMs: item.whenMs,
          title: item.title,
          body: item.body,
          status: InboxStatus.opened,
        );
      } else if (_isExpiredForMissed(item.whenMs, now)) {
        // 已過期5分鐘以上但未開啟 → missed
        // 如果已有 missed 記錄則保留（避免覆蓋）
        if (!all.containsKey(key)) {
          all[key] = InboxItem(
            productId: item.productId,
            contentItemId: item.contentItemId,
            whenMs: item.whenMs,
            title: item.title,
            body: item.body,
            status: InboxStatus.missed,
          );
        }
      } else {
        // 未來 → scheduled
        // 如果已有 missed 記錄則保留（避免新排程覆蓋舊的 missed）
        if (!all.containsKey(key)) {
          all[key] = item;
        }
      }
    }

    return all.values.toList();
  }

  static Future<List<InboxItem>> _loadItems(String key) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((m) => InboxItem.fromJson(
              m.map((k, v) => MapEntry(k.toString(), v))))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveItems(String key, List<InboxItem> items) async {
    final sp = await SharedPreferences.getInstance();
    final list = items.map((item) => item.toJson()).toList();
    await sp.setString(key, jsonEncode(list));
  }

  /// 更新或插入排程項目
  /// 注意：只會更新/新增 scheduled 狀態的項目，不會影響已過期（missed）或已開啟（opened）的記錄
  /// 
  /// 邏輯：
  /// 1. 如果已存在該 contentItemId 的舊排程且已過期5分鐘以上但未開啟 → 移到 missed 列表
  /// 2. 移除舊的 scheduled 記錄
  /// 3. 如果新時間是未來 → 加入 scheduled
  static Future<void> upsertScheduled({
    required String uid,
    required String productId,
    required String contentItemId,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    if (uid.isEmpty || productId.isEmpty || contentItemId.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final opened = await loadOpenedGlobal(uid);
    
    // ✅ 如果已開啟，則不再重新排程（opened 狀態優先）
    if (opened.containsKey(contentItemId)) {
      if (kDebugMode) {
        debugPrint('ℹ️ upsertScheduled: contentItemId=$contentItemId 已開啟，不重新排程');
      }
      return;
    }
    
    final scheduledKey = _kScheduled(uid);
    final missedKey = _kMissed(uid);
    
    final scheduled = await _loadItems(scheduledKey);
    final missed = await _loadItems(missedKey);
    
    // 檢查是否有舊的 scheduled 記錄（使用 contentItemId 判斷）
    final oldItemIndex = scheduled.indexWhere(
      (item) => item.contentItemId == contentItemId,
    );
    
    // 如果找到舊記錄且已過期5分鐘以上但未開啟，先移到 missed 列表
    if (oldItemIndex >= 0) {
      final oldItem = scheduled[oldItemIndex];
      if (_isExpiredForMissed(oldItem.whenMs, now)) {
        // 檢查是否已經在 missed 列表中（使用 contentItemId 判斷）
        final alreadyMissed = missed.any((item) =>
            item.contentItemId == contentItemId);
        
        if (!alreadyMissed) {
          // 移到 missed 列表
          final newMissed = List<InboxItem>.from(missed);
          newMissed.add(InboxItem(
            productId: oldItem.productId,
            contentItemId: oldItem.contentItemId,
            whenMs: oldItem.whenMs,
            title: oldItem.title,
            body: oldItem.body,
            status: InboxStatus.missed,
          ));
          await _saveItems(missedKey, newMissed);
        }
      }
      
      // 移除舊的 scheduled 記錄
      scheduled.removeAt(oldItemIndex);
    }

    // 只有當新時間是未來時，才加入 scheduled
    if (when.millisecondsSinceEpoch >= now) {
      scheduled.add(InboxItem(
        productId: productId,
        contentItemId: contentItemId,
        whenMs: when.millisecondsSinceEpoch,
        title: title,
        body: body,
        status: InboxStatus.scheduled,
      ));
    }

    await _saveItems(scheduledKey, scheduled);
  }

  /// 掃描並將過期的 scheduled 標記為 missed
  /// 
  /// 注意：
  /// - opened 狀態優先：已開啟的內容不會標記為 missed
  /// - 去重：使用 contentItemId 作為唯一鍵，避免重複標記
  /// - 過期標準：當前時間 - 排程時間 >= 5分鐘
  static Future<void> sweepMissed(String uid) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final opened = await loadOpenedGlobal(uid);

    final scheduledKey = _kScheduled(uid);
    final missedKey = _kMissed(uid);

    final scheduled = await _loadItems(scheduledKey);
    final missed = await _loadItems(missedKey);

    // ✅ 使用 contentItemId 作為唯一鍵進行去重
    final missedSet = <String>{}; // contentItemId 集合
    for (final item in missed) {
      missedSet.add(item.contentItemId);
    }

    final newScheduled = <InboxItem>[];
    final newMissed = <InboxItem>[];

    // 處理 scheduled 項目
    for (final item in scheduled) {
      final key = item.contentItemId;
      
      if (opened.containsKey(item.contentItemId)) {
        // 已開啟，不加入任何列表（opened 優先）
        continue;
      } else if (_isExpiredForMissed(item.whenMs, now)) {
        // 已過期5分鐘以上且未開啟 → 加入 missed
        if (!missedSet.contains(key)) {
          newMissed.add(InboxItem(
            productId: item.productId,
            contentItemId: item.contentItemId,
            whenMs: item.whenMs,
            title: item.title,
            body: item.body,
            status: InboxStatus.missed,
          ));
          missedSet.add(key);
        }
      } else {
        // 未來 → 保留在 scheduled
        newScheduled.add(item);
      }
    }

    // 保留現有的 missed（如果還沒被開啟）
    for (final item in missed) {
      if (!opened.containsKey(item.contentItemId)) {
        final key = item.contentItemId;
        if (!missedSet.contains(key)) {
          newMissed.add(item);
          missedSet.add(key);
        }
      }
    }

    await _saveItems(scheduledKey, newScheduled);
    await _saveItems(missedKey, newMissed);
  }

  /// 清除所有錯過的項目
  static Future<void> clearMissed(String uid) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kMissed(uid));
  }

  /// 讀取 missed 的 contentItemId 集合（用於排程/時間表排除）
  /// 
  /// 注意：
  /// - 已開啟的內容不會被包含（opened 優先於 missed）
  /// - 確保排程時不會選擇已錯過的內容
  static Future<Set<String>> loadMissedContentItemIds(String uid) async {
    final missed = await _loadItems(_kMissed(uid));
    final opened = await loadOpenedGlobal(uid);
    
    // ✅ 過濾掉已開啟的內容（opened 優先於 missed）
    final missedIds = <String>{};
    for (final item in missed) {
      // 如果已開啟，則不加入 missed 列表（opened 優先）
      if (!opened.containsKey(item.contentItemId)) {
        missedIds.add(item.contentItemId);
      }
    }
    
    if (kDebugMode && missedIds.isNotEmpty) {
      debugPrint('📋 loadMissedContentItemIds: 載入 ${missedIds.length} 個 missed 的 contentItemId（已過濾 opened）');
    }
    
    return missedIds;
  }

  /// 更積極的過期掃描：1 分鐘後就標記為 missed
  /// 
  /// 用途：處理用戶滑掉通知但回調沒觸發的情況
  /// 當 app 恢復前景時調用，使用更短的過期時間（1 分鐘）
  /// 
  /// 注意：
  /// - 此方法只在 app 恢復前景時調用
  /// - 使用 1 分鐘過期時間，比標準的 5 分鐘更積極
  /// - opened 狀態仍然優先
  static Future<void> sweepExpiredButNotMissed(String uid) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final opened = await loadOpenedGlobal(uid);

    final scheduledKey = _kScheduled(uid);
    final missedKey = _kMissed(uid);

    final scheduled = await _loadItems(scheduledKey);
    final missed = await _loadItems(missedKey);

    // 使用 1 分鐘作為更積極的過期時間
    const aggressiveThresholdMs = 1 * 60 * 1000; // 1分鐘

    final missedSet = <String>{};
    for (final item in missed) {
      missedSet.add(item.contentItemId);
    }

    final newScheduled = <InboxItem>[];
    final newMissed = <InboxItem>[];
    bool hasChanges = false;

    for (final item in scheduled) {
      final key = item.contentItemId;
      
      if (opened.containsKey(item.contentItemId)) {
        // 已開啟，不加入任何列表
        continue;
      } else if (item.whenMs < (now - aggressiveThresholdMs)) {
        // 已過期 1 分鐘以上且未開啟 → 加入 missed
        if (!missedSet.contains(key)) {
          newMissed.add(InboxItem(
            productId: item.productId,
            contentItemId: item.contentItemId,
            whenMs: item.whenMs,
            title: item.title,
            body: item.body,
            status: InboxStatus.missed,
          ));
          missedSet.add(key);
          hasChanges = true;
          
          if (kDebugMode) {
            debugPrint('🔴 sweepExpiredButNotMissed: ${item.contentItemId} 已過期 1 分鐘，標記為 missed');
          }
        }
      } else {
        // 未來或剛過期（未滿 1 分鐘） → 保留在 scheduled
        newScheduled.add(item);
      }
    }

    // 保留現有的 missed（如果還沒被開啟）
    for (final item in missed) {
      if (!opened.containsKey(item.contentItemId)) {
        newMissed.add(item);
      }
    }

    if (hasChanges) {
      await _saveItems(scheduledKey, newScheduled);
      await _saveItems(missedKey, newMissed);
      
      if (kDebugMode) {
        debugPrint('✅ sweepExpiredButNotMissed: 已處理過期通知');
      }
    }
  }
}
