import 'package:flutter/foundation.dart';
import '../../notifications/push_exclusion_store.dart';
import '../../services/progress_service.dart';

/// 通知動作處理器（統一入口）
/// 
/// 原則：
/// 1. 所有通知相關的狀態變更必須通過 ProgressService
/// 2. UI 不准直接寫 Firestore / SharedPreferences
/// 3. 先寫本地 queue → 立即更新 UI → 背景補寫 Firestore
class NotificationActionHandler {
  final ProgressService _progressService;

  NotificationActionHandler({ProgressService? progressService})
      : _progressService = progressService ?? ProgressService();

  /// 處理「已學會」動作
  Future<void> handleLearned({
    required String uid,
    required Map<String, dynamic> payload,
  }) async {
    final contentId = (payload['contentItemId'] ?? payload['contentId'] ?? '').toString();
    final topicId = (payload['topicId'] ?? '').toString();
    final productId = (payload['productId'] ?? '').toString();
    final pushOrder = payload['pushOrder'] as int?;

    if (contentId.isEmpty || topicId.isEmpty || productId.isEmpty) {
      if (kDebugMode) {
        debugPrint('⚠️ handleLearned: 缺少必要欄位 payload=$payload');
      }
      return;
    }

    await _progressService.markLearned(
      uid: uid,
      contentId: contentId,
      topicId: topicId,
      productId: productId,
      pushOrder: pushOrder,
    );

    if (kDebugMode) {
      debugPrint('✅ handleLearned: contentId=$contentId');
    }
  }

  /// 處理「稍候再學」動作（延後 5 分鐘）
  Future<void> handleSnooze({
    required String uid,
    required Map<String, dynamic> payload,
    Duration snoozeDuration = const Duration(minutes: 5),
  }) async {
    final contentId = (payload['contentItemId'] ?? payload['contentId'] ?? '').toString();
    final topicId = (payload['topicId'] ?? '').toString();
    final productId = (payload['productId'] ?? '').toString();
    final pushOrder = payload['pushOrder'] as int?;

    if (contentId.isEmpty || topicId.isEmpty || productId.isEmpty) {
      if (kDebugMode) {
        debugPrint('⚠️ handleSnooze: 缺少必要欄位 payload=$payload');
      }
      return;
    }

    final snoozedUntil = DateTime.now().add(snoozeDuration);

    await _progressService.markSnoozed(
      uid: uid,
      contentId: contentId,
      topicId: topicId,
      productId: productId,
      snoozedUntil: snoozedUntil,
      pushOrder: pushOrder,
    );

    if (kDebugMode) {
      debugPrint('✅ handleSnooze: contentId=$contentId, until=$snoozedUntil');
    }
  }

  /// 處理「已開啟」動作
  Future<void> handleOpened({
    required String uid,
    required Map<String, dynamic> payload,
  }) async {
    final contentId = (payload['contentItemId'] ?? payload['contentId'] ?? '').toString();
    final topicId = (payload['topicId'] ?? '').toString();
    final productId = (payload['productId'] ?? '').toString();
    final pushOrder = payload['pushOrder'] as int?;

    if (contentId.isEmpty || topicId.isEmpty || productId.isEmpty) {
      if (kDebugMode) {
        debugPrint('⚠️ handleOpened: 缺少必要欄位 payload=$payload');
      }
      return;
    }

    await _progressService.markOpened(
      uid: uid,
      contentId: contentId,
      topicId: topicId,
      productId: productId,
      pushOrder: pushOrder,
    );

    if (kDebugMode) {
      debugPrint('✅ handleOpened: contentId=$contentId');
    }
  }

  /// 處理「滑掉」動作
  Future<void> handleDismissed({
    required String uid,
    required Map<String, dynamic> payload,
  }) async {
    final contentId = (payload['contentItemId'] ?? payload['contentId'] ?? '').toString();
    final topicId = (payload['topicId'] ?? '').toString();
    final productId = (payload['productId'] ?? '').toString();
    final pushOrder = payload['pushOrder'] as int?;

    if (contentId.isEmpty || topicId.isEmpty || productId.isEmpty) {
      if (kDebugMode) {
        debugPrint('⚠️ handleDismissed: 缺少必要欄位 payload=$payload');
      }
      return;
    }

    // ✅ 標記為 missed
    await PushExclusionStore.markMissed(uid, contentId);

    // ✅ 更新進度狀態
    await _progressService.markDismissed(
      uid: uid,
      contentId: contentId,
      topicId: topicId,
      productId: productId,
      pushOrder: pushOrder,
    );

    if (kDebugMode) {
      debugPrint('✅ handleDismissed: contentId=$contentId (已標記為 missed)');
    }
  }
}
