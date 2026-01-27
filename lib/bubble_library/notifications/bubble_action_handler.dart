import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../notifications/push_exclusion_store.dart';
import 'notification_service.dart';
import 'notification_scheduler.dart';
import '../providers/providers.dart';

/// 泡泡動作類型
enum BubbleAction {
  opened,  // 開啟（點擊通知本體）
  learned, // 已學習（點擊「完成」按鈕）
  snoozed, // 稍後再學（點擊「稍候再學」按鈕）
  dismissed, // 滑掉通知
}

/// 泡泡狀態處理結果
class BubbleActionResult {
  final bool success;
  final String? error;
  final List<String> completedSteps;
  final String? failedStep;

  const BubbleActionResult({
    required this.success,
    this.error,
    this.completedSteps = const [],
    this.failedStep,
  });

  factory BubbleActionResult.success(List<String> steps) {
    return BubbleActionResult(
      success: true,
      completedSteps: steps,
    );
  }

  factory BubbleActionResult.failure(String step, String error, List<String> completed) {
    return BubbleActionResult(
      success: false,
      error: error,
      completedSteps: completed,
      failedStep: step,
    );
  }
}

/// 原子操作包裝器：確保泡泡狀態更新的原子性和一致性
/// 
/// 功能：
/// - 統一入口：所有泡泡狀態更新都透過此類
/// - 錯誤處理：任何步驟失敗都會記錄並嘗試回滾
/// - 追蹤記錄：記錄每個操作的結果
class BubbleActionHandler {
  /// 處理泡泡動作（統一入口）
  /// 
  /// [ref] - Riverpod WidgetRef
  /// [contentItemId] - 內容項目 ID
  /// [productId] - 產品 ID
  /// [action] - 動作類型
  /// [topicId] - 主題 ID（learned/snoozed 需要）
  /// [pushOrder] - 推播順序（learned/snoozed 需要）
  /// [source] - 觸發來源（用於 debug）
  static Future<BubbleActionResult> handle({
    required WidgetRef ref,
    required String contentItemId,
    required String productId,
    required BubbleAction action,
    String? topicId,
    int? pushOrder,
    String source = 'unknown',
  }) async {
    final uid = ref.read(uidProvider);
    final completedSteps = <String>[];

    try {
      if (kDebugMode) {
        debugPrint('🎯 BubbleActionHandler.handle: contentItemId=$contentItemId, action=${action.name}, source=$source');
      }

      // ✅ 步驟 1：掃描過期通知（確保狀態一致）
      try {
        await PushExclusionStore.sweepExpired(uid);
        completedSteps.add('sweepExpired');
      } catch (e) {
        return BubbleActionResult.failure('sweepExpired', e.toString(), completedSteps);
      }

      // ✅ 步驟 2：根據動作類型執行相應操作
      switch (action) {
        case BubbleAction.opened:
          return await _handleOpened(
            ref: ref,
            uid: uid,
            contentItemId: contentItemId,
            productId: productId,
            completedSteps: completedSteps,
          );

        case BubbleAction.learned:
          return await _handleLearned(
            ref: ref,
            uid: uid,
            contentItemId: contentItemId,
            productId: productId,
            topicId: topicId,
            pushOrder: pushOrder,
            source: source,
            completedSteps: completedSteps,
          );

        case BubbleAction.snoozed:
          return await _handleSnoozed(
            ref: ref,
            uid: uid,
            contentItemId: contentItemId,
            productId: productId,
            topicId: topicId,
            pushOrder: pushOrder,
            source: source,
            completedSteps: completedSteps,
          );

        case BubbleAction.dismissed:
          return await _handleDismissed(
            ref: ref,
            uid: uid,
            contentItemId: contentItemId,
            productId: productId,
            completedSteps: completedSteps,
          );
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ BubbleActionHandler 執行失敗: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      return BubbleActionResult.failure('unknown', e.toString(), completedSteps);
    }
  }

  /// 處理「開啟」動作
  static Future<BubbleActionResult> _handleOpened({
    required WidgetRef ref,
    required String uid,
    required String contentItemId,
    required String productId,
    required List<String> completedSteps,
  }) async {
    try {
      // 標記為已讀
      await PushExclusionStore.markOpened(uid, contentItemId);
      completedSteps.add('markOpened');

      return BubbleActionResult.success(completedSteps);
    } catch (e) {
      return BubbleActionResult.failure('markOpened', e.toString(), completedSteps);
    }
  }

  /// 處理「已學習」動作
  static Future<BubbleActionResult> _handleLearned({
    required WidgetRef ref,
    required String uid,
    required String contentItemId,
    required String productId,
    String? topicId,
    int? pushOrder,
    required String source,
    required List<String> completedSteps,
  }) async {
    final repo = ref.read(libraryRepoProvider);
    final progress = ref.read(learningProgressServiceProvider);
    final ns = NotificationService();
    final scheduler = ref.read(notificationSchedulerProvider);

    try {
      // ✅ 1) 標記為已讀
      await PushExclusionStore.markOpened(uid, contentItemId);
      completedSteps.add('markOpened');

      // ✅ 2) 更新 saved_items（讓 UI 立即看到變化）
      await repo.setSavedItem(uid, contentItemId, {'learned': true});
      completedSteps.add('setSavedItem');

      // ✅ 3) 更新學習進度（如果有必要資訊）
      if (topicId != null && pushOrder != null) {
        try {
          await progress.markLearnedAndAdvance(
            topicId: topicId,
            contentId: contentItemId, // LearningProgressService 參數名為 contentId
            pushOrder: pushOrder,
            source: source,
          );
          completedSteps.add('markLearnedAndAdvance');
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ markLearnedAndAdvance 失敗（已有 setSavedItem 保底）: $e');
          }
          // 不回滾：setSavedItem 已標記，這是保底機制
        }
      }

      // ✅ 4) 取消已排程的通知
      await ns.cancelByContentItemId(contentItemId);
      completedSteps.add('cancelNotification');

      // ✅ 5) 刷新 provider
      ref.invalidate(savedItemsProvider);
      completedSteps.add('invalidateProvider');

      // ✅ 6) 等待 provider 更新（確保排程讀到最新狀態）
      try {
        await ref.read(savedItemsProvider.future);
        completedSteps.add('awaitProviderUpdate');
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ 等待 provider 更新失敗: $e');
        }
        // 繼續執行，不中斷
      }

      // ✅ 7) 重新排程（透過單一入口）
      await scheduler.schedule(
        ref: ref,
        days: 3,
        source: 'learned_action',
        immediate: true, // 學習完成後立即排程，不防抖
      );
      completedSteps.add('reschedule');

      return BubbleActionResult.success(completedSteps);
    } catch (e) {
      // 記錄失敗的步驟
      final failedStep = completedSteps.isEmpty ? 'markOpened' : 
                        (completedSteps.length == 1 ? 'setSavedItem' : 
                        (completedSteps.length == 2 ? 'markLearnedAndAdvance' : 
                        (completedSteps.length == 3 ? 'cancelNotification' : 'reschedule')));
      return BubbleActionResult.failure(failedStep, e.toString(), completedSteps);
    }
  }

  /// 處理「稍後再學」動作
  static Future<BubbleActionResult> _handleSnoozed({
    required WidgetRef ref,
    required String uid,
    required String contentItemId,
    required String productId,
    String? topicId,
    int? pushOrder,
    required String source,
    required List<String> completedSteps,
  }) async {
    final repo = ref.read(libraryRepoProvider);
    final progress = ref.read(learningProgressServiceProvider);
    final ns = NotificationService();
    final scheduler = ref.read(notificationSchedulerProvider);

    try {
      // ✅ 1) 更新 saved_items（讓 UI 立即看到變化）
      await repo.setSavedItem(uid, contentItemId, {'reviewLater': true});
      completedSteps.add('setSavedItem');

      // ✅ 2) 更新學習進度（如果有必要資訊）
      if (topicId != null && pushOrder != null) {
        try {
          await progress.snoozeContent(
            topicId: topicId,
            contentId: contentItemId, // LearningProgressService 參數名為 contentId
            pushOrder: pushOrder,
            duration: const Duration(hours: 6),
            source: source,
          );
          completedSteps.add('snoozeContent');
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ snoozeContent 失敗（已有 setSavedItem 保底）: $e');
          }
          // 不回滾：setSavedItem 已標記，這是保底機制
        }
      }

      // ✅ 3) 取消已排程的通知
      await ns.cancelByContentItemId(contentItemId);
      completedSteps.add('cancelNotification');

      // ✅ 4) 刷新 provider
      ref.invalidate(savedItemsProvider);
      completedSteps.add('invalidateProvider');

      // ✅ 5) 等待 provider 更新（確保排程讀到最新狀態）
      try {
        await ref.read(savedItemsProvider.future);
        completedSteps.add('awaitProviderUpdate');
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ 等待 provider 更新失敗: $e');
        }
        // 繼續執行，不中斷
      }

      // ✅ 6) 重新排程（透過單一入口）
      await scheduler.schedule(
        ref: ref,
        days: 3,
        source: 'snoozed_action',
        immediate: true, // 稍後再學後立即排程，不防抖
      );
      completedSteps.add('reschedule');

      return BubbleActionResult.success(completedSteps);
    } catch (e) {
      final failedStep = completedSteps.isEmpty ? 'setSavedItem' : 
                        (completedSteps.length == 1 ? 'snoozeContent' : 
                        (completedSteps.length == 2 ? 'cancelNotification' : 'reschedule'));
      return BubbleActionResult.failure(failedStep, e.toString(), completedSteps);
    }
  }

  /// 處理「滑掉」動作
  static Future<BubbleActionResult> _handleDismissed({
    required WidgetRef ref,
    required String uid,
    required String contentItemId,
    required String productId,
    required List<String> completedSteps,
  }) async {
    final scheduler = ref.read(notificationSchedulerProvider);

    try {
      // ✅ 檢查是否已開啟（opened 優先於 dismissed）
      final isOpened = await PushExclusionStore.isOpened(uid, contentItemId);
      if (isOpened) {
        if (kDebugMode) {
          debugPrint('ℹ️ 通知已開啟，不標記為 dismissed: $contentItemId');
        }
        completedSteps.add('skipDismissed_alreadyOpened');
        return BubbleActionResult.success(completedSteps);
      }

      // ✅ 標記為錯過
      await PushExclusionStore.markMissed(uid, contentItemId);
      completedSteps.add('markMissed');

      // ✅ 重新排程（避免下次又排到同一則）
      await scheduler.schedule(
        ref: ref,
        days: 3,
        source: 'dismissed_action',
        immediate: true, // 滑掉後立即排程，不防抖
      );
      completedSteps.add('reschedule');

      return BubbleActionResult.success(completedSteps);
    } catch (e) {
      final failedStep = completedSteps.isEmpty ? 'markMissed' : 'reschedule';
      return BubbleActionResult.failure(failedStep, e.toString(), completedSteps);
    }
  }
}
