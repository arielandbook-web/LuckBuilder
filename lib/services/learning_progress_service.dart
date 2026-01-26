import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LearningProgressService {
  LearningProgressService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in');
    return u.uid;
  }

  /// Schema (recommended)
  /// users/{uid}/topicProgress/{topicId}
  /// users/{uid}/contentState/{contentId}
  /// users/{uid}/saved_items/{contentId}  ← 同步寫入，供 UI 和推播排程使用

  DocumentReference<Map<String, dynamic>> _topicProgressRef(String topicId) {
    return _db.collection('users').doc(_uid).collection('topicProgress').doc(topicId);
  }

  DocumentReference<Map<String, dynamic>> _contentStateRef(String contentId) {
    return _db.collection('users').doc(_uid).collection('contentState').doc(contentId);
  }

  /// ✅ saved_items 路徑（供 UI 讀取 learned 狀態）
  DocumentReference<Map<String, dynamic>> _savedItemRef(String contentId) {
    return _db.collection('users').doc(_uid).collection('saved_items').doc(contentId);
  }

  /// 防連點、防跳號：同一個 contentId 被重複按「我學會了」不會把 nextPushOrder +2
  ///
  /// payload must include: topicId, contentId, pushOrder (int)
  /// 
  /// ✅ 同時寫入 saved_items（供 UI 和推播排程讀取）
  Future<void> markLearnedAndAdvance({
    required String topicId,
    required String contentId,
    required int pushOrder,
    String? source, // e.g. 'ios_action'
  }) async {
    final now = Timestamp.now();
    final nextCandidate = pushOrder + 1;

    await _db.runTransaction((tx) async {
      final contentRef = _contentStateRef(contentId);
      final progressRef = _topicProgressRef(topicId);
      final savedRef = _savedItemRef(contentId); // ✅ saved_items 路徑

      // ✅ Firestore 事務規則：所有讀取必須在所有寫入之前
      // 步驟 1：執行所有讀取操作
      final contentSnap = await tx.get(contentRef);
      final progSnap = await tx.get(progressRef);

      // 已經 learned → 直接 return (避免 double increment)
      if (contentSnap.exists) {
        final data = contentSnap.data()!;
        final status = (data['status'] as String?) ?? '';
        if (status == 'learned') return;
      }

      // 讀取 progress，讓 nextPushOrder 至少到 pushOrder+1（不倒退）
      int currentNext = 1;
      if (progSnap.exists) {
        final p = progSnap.data()!;
        final v = p['nextPushOrder'];
        if (v is int) currentNext = v;
      }

      final newNext = (currentNext >= nextCandidate) ? currentNext : nextCandidate;

      // ✅ 步驟 2：執行所有寫入操作（在讀取之後）
      // 寫 contentState: learned
      tx.set(contentRef, {
        'topicId': topicId,
        'contentId': contentId,
        'pushOrder': pushOrder,
        'status': 'learned',
        'learnedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (source != null) 'source': source,
      }, SetOptions(merge: true));

      // ✅ 同步寫入 saved_items（供 UI 讀取 learned 狀態、推播排程優先未完成）
      tx.set(savedRef, {
        'learned': true,
        'learnedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 寫 progress
      tx.set(progressRef, {
        'topicId': topicId,
        'nextPushOrder': newNext,
        'updatedAt': FieldValue.serverTimestamp(),
        // 可選：紀錄最近一次完成
        'lastLearned': {
          'contentId': contentId,
          'pushOrder': pushOrder,
          'at': now,
        },
      }, SetOptions(merge: true));
    });
  }

  /// 之後再學：只做 snooze，不推進 nextPushOrder
  /// 
  /// ✅ 同時寫入 saved_items（供 UI 和推播排程讀取）
  Future<void> snoozeContent({
    required String topicId,
    required String contentId,
    required int pushOrder,
    Duration duration = const Duration(hours: 6),
    String? source, // e.g. 'ios_action'
  }) async {
    final until = Timestamp.fromDate(DateTime.now().add(duration));

    await _db.runTransaction((tx) async {
      final contentRef = _contentStateRef(contentId);
      final savedRef = _savedItemRef(contentId); // ✅ saved_items 路徑
      final snap = await tx.get(contentRef);

      // 如果已經 learned，就不用 snooze
      if (snap.exists) {
        final data = snap.data()!;
        final status = (data['status'] as String?) ?? '';
        if (status == 'learned') return;
      }

      tx.set(contentRef, {
        'topicId': topicId,
        'contentId': contentId,
        'pushOrder': pushOrder,
        'status': 'snoozed',
        'snoozeUntil': until,
        'updatedAt': FieldValue.serverTimestamp(),
        if (source != null) 'source': source,
      }, SetOptions(merge: true));

      // ✅ 同步寫入 saved_items（reviewLater = true 讓 UI 知道是稍後再學）
      tx.set(savedRef, {
        'reviewLater': true,
        'snoozeUntil': until,
      }, SetOptions(merge: true));
    });
  }
}
