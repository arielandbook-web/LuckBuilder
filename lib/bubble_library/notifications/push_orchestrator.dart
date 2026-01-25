import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/global_push_settings.dart';
import '../models/push_config.dart';
import '../models/user_library.dart';
import '../models/content_item.dart';
import '../providers/providers.dart';
import 'notification_service.dart';
import 'push_scheduler.dart';
// ✅ 新增：真排序（日常順序）+ skip next（本機）
import '../../notifications/daily_routine_store.dart';
import '../../notifications/skip_next_store.dart';
// ✅ 新增：排程時寫入 Inbox（本機真資料）
import '../../notifications/notification_inbox_store.dart';
// ✅ 新增：排程快取同步
import 'scheduled_push_cache.dart';
import '../../notifications/push_timeline_provider.dart';
// ✅ 新增：衝突檢查
import 'push_schedule_conflict_checker.dart';

/// 重排結果，供 UI 顯示超過每日上限等提示
class RescheduleResult {
  final bool overCap;
  final int totalEffectiveFreq;
  final int dailyCap;
  final int scheduledCount;

  const RescheduleResult({
    required this.overCap,
    required this.totalEffectiveFreq,
    required this.dailyCap,
    required this.scheduledCount,
  });
}

class PushOrchestrator {
  static Map<String, dynamic>? decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// 重排未來 N 天（預設 3 天），避免 iOS 64 排程上限
  /// ✅ 已整合：
  /// - 真排序：DailyRoutine（本機 orderedProductIds）
  /// - Skip next：本機 skip contentItemId（只在 reschedule 時消耗）
  /// - Missed 狀態：自動過濾已滑掉/錯過的內容
  /// 
  /// [overrideGlobal] 可選：如果提供，會優先使用此設定（用於立即更新時避免讀到舊值）
  static Future<RescheduleResult> rescheduleNextDays({
    required WidgetRef ref,
    int days = 3,
    GlobalPushSettings? overrideGlobal,
  }) async {
    final uid = ref.read(uidProvider);

    // ✅ 先執行 sweepMissed，確保已過期的排程被移到 missed 列表
    // 這樣可以避免重新排程已過期但未開啟的內容
    await NotificationInboxStore.sweepMissed(uid);

    // ✅ 強制刷新所有相關 provider，確保讀到最新狀態
    if (kDebugMode) {
      debugPrint('🔄 強制刷新所有相關 provider...');
    }
    ref.invalidate(libraryProductsProvider);
    ref.invalidate(savedItemsProvider);
    ref.invalidate(productsMapProvider);

    // ✅ 等待關鍵 provider 更新完成
    final lib = await ref.read(libraryProductsProvider.future);
    final productsMap = await ref.read(productsMapProvider.future);

    GlobalPushSettings global;
    if (overrideGlobal != null) {
      global = overrideGlobal;
    } else {
      try {
        ref.invalidate(globalPushSettingsProvider);
        global = await ref.read(globalPushSettingsProvider.future);
      } catch (_) {
        global = GlobalPushSettings.defaults();
      }
    }

    Map<String, SavedContent> savedMap;
    try {
      // ✅ 已在上面 invalidate，這裡會讀到最新狀態
      savedMap = await ref.read(savedItemsProvider.future);
    } catch (_) {
      savedMap = {};
    }

    // ✅ Missed 清單（本機）：滑掉/錯過的內容，重排時應排除
    final missedContentItemIds =
        await NotificationInboxStore.loadMissedContentItemIds(uid);

    // ✅ Skip 清單（本機）：全域 + scoped(每商品)
    final globalSkip = await SkipNextStore.load(uid);
    // scopedSkipCache：避免每個 task 都 load 一次
    final scopedSkipCache = <String, Set<String>>{};

    // ✅ 真排序：日常順序（本機）
    final routine = await DailyRoutineStore.load(uid);
    final productOrder = List<String>.from(routine.orderedProductIds);

    // 建 library map（只保留存在的 product）
    final libMap = <String, UserLibraryProduct>{};
    for (final p in lib) {
      if (!productsMap.containsKey(p.productId)) continue;
      libMap[p.productId] = p;
    }

    // 只抓推播中的 products content（效率好）
    final contentByProduct = <String, List<dynamic>>{};
    for (final entry in libMap.entries) {
      if (!entry.value.pushEnabled || entry.value.isHidden) continue;
      final list = await ref.read(contentByProductProvider(entry.key).future);
      contentByProduct[entry.key] = list;
    }

    // ✅ 診斷：顯示排程前的狀態
    if (kDebugMode) {
      debugPrint('📅 ===== rescheduleNextDays 開始 =====');
      debugPrint('  - uid: $uid');
      debugPrint('  - days: $days');
      debugPrint('  - global.enabled: ${global.enabled}');
      debugPrint('  - global.dailyTotalCap: ${global.dailyTotalCap}');
      debugPrint('  - global.quietHours: ${global.quietHours.start.hour}:${global.quietHours.start.minute} - ${global.quietHours.end.hour}:${global.quietHours.end.minute}');
      debugPrint('  - libMap 產品數量: ${libMap.length}');
      
      final pushingForLog = libMap.values.where((p) => p.pushEnabled && !p.isHidden).toList();
      debugPrint('  - 推播中的產品: ${pushingForLog.length}');
      for (final p in pushingForLog) {
        final cfg = p.pushConfig;
        debugPrint('    • ${p.productId}:');
        debugPrint('      - pushEnabled: ${p.pushEnabled}, hidden: ${p.isHidden}');
        debugPrint('      - freq: ${cfg.freqPerDay}, timeMode: ${cfg.timeMode.name}');
        debugPrint('      - presetSlots: ${cfg.presetSlots}');
        if (cfg.timeMode == PushTimeMode.custom) {
          final customTimesStr = cfg.customTimes
              .map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
              .join(', ');
          debugPrint('      - customTimes: [$customTimesStr] (數量: ${cfg.customTimes.length})');
          if (cfg.customTimes.isEmpty) {
            debugPrint('      ⚠️ 警告：timeMode 為 custom 但 customTimes 為空！');
          }
        } else {
          debugPrint('      - customTimes: [] (未使用自訂時間模式)');
        }
        debugPrint('      - daysOfWeek: ${cfg.daysOfWeek}');
      }
      
      debugPrint('  - contentByProduct 數量: ${contentByProduct.length}');
      for (final entry in contentByProduct.entries) {
        debugPrint('    • ${entry.key}: ${entry.value.length} 個內容項目');
      }
    }

    // ✅ 衝突檢查
    if (kDebugMode) {
      try {
        final contentByProductTyped = contentByProduct.map(
          (k, v) => MapEntry(k, v.cast<ContentItem>()),
        );
        final conflictReports = await PushScheduleConflictChecker.checkAll(
          global: global,
          libraryByProductId: libMap,
          contentByProduct: contentByProductTyped,
          savedMap: savedMap,
          uid: uid,
        );

        if (conflictReports.isNotEmpty) {
          debugPrint('⚠️  ===== 衝突檢查報告 =====');
          debugPrint(PushScheduleConflictChecker.formatReports(conflictReports));
          debugPrint('⚠️  ===== 衝突檢查結束 =====');
        } else {
          debugPrint('✅ 衝突檢查：未發現衝突');
        }
      } catch (e, stackTrace) {
        debugPrint('❌ 衝突檢查失敗: $e');
        debugPrint('Stack trace: $stackTrace');
        // 不中斷排程流程，繼續執行
      }
    }

    // ✅ 有效頻率：推播中產品的 freqPerDay 總和
    final pushingProducts = libMap.values.where((p) => p.pushEnabled && !p.isHidden).toList();
    final totalEffectiveFreq = pushingProducts.fold<int>(0, (s, p) => s + p.pushConfig.freqPerDay);
    final dailyCap = global.dailyTotalCap.clamp(1, 50);
    final overCap = totalEffectiveFreq > dailyCap;

    // ✅ 建 schedule（已帶 productOrder → 真排序）
    final tasks = PushScheduler.buildSchedule(
      now: DateTime.now(),
      days: days,
      global: global,
      libraryByProductId: libMap,
      contentByProduct: contentByProduct.map((k, v) => MapEntry(k, v.cast())),
      savedMap: savedMap,
      iosSafeMaxScheduled: 60,
      productOrder: productOrder,
      missedContentItemIds: missedContentItemIds,
    );

    // ✅ 診斷：顯示排程結果
    if (kDebugMode) {
      debugPrint('  - 產生的 tasks: ${tasks.length}');
      if (tasks.isEmpty && global.enabled) {
        debugPrint('  ⚠️ 警告：推播已啟用但沒有產生任何排程！');
        debugPrint('  可能原因：');
        debugPrint('    1. 沒有啟用推播的產品');
        debugPrint('    2. 產品沒有內容項目');
        debugPrint('    3. 所有時間都在勿擾時段內');
        debugPrint('    4. 星期幾設定不允許今天推播');
      } else {
        for (int i = 0; i < tasks.length && i < 5; i++) {
          final t = tasks[i];
          debugPrint('    [$i] ${t.when} - ${t.productId} - ${t.item.id}');
        }
        if (tasks.length > 5) {
          debugPrint('    ... 還有 ${tasks.length - 5} 筆');
        }
      }
      debugPrint('📅 ===== rescheduleNextDays 結束 =====');
    }

    // ✅ 先取消全部，再依新 tasks schedule
    final ns = NotificationService();
    final cache = ScheduledPushCache();
    
    // ✅ 清除排程前，不需再次執行 sweepMissed（已在函數開頭執行過）
    await ns.cancelAll();
    await cache.clear(); // ✅ 同步清除快取

    int idSeed = DateTime.now().millisecondsSinceEpoch.remainder(1000000);

    // ✅ 這輪 reschedule 會消耗掉的 skip（只在 reschedule 才消耗）
    final consumedGlobal = <String>{};
    final consumedScoped = <String, Set<String>>{};

    // ✅ 已完成通知：每個產品只排程一次（當推播到最後一則時）
    final completionScheduledForProduct = <String>{};

    for (final t in tasks) {
      final contentItemId = t.item.id;

      // 1) 全域 skip
      if (globalSkip.contains(contentItemId)) {
        consumedGlobal.add(contentItemId);
        continue;
      }

      // 2) scoped skip（每商品）
      final scoped = scopedSkipCache.putIfAbsent(
        t.productId,
        () => <String>{},
      );
      if (scoped.isEmpty) {
        // 第一次需要 load
        scoped.addAll(await SkipNextStore.loadForProduct(uid, t.productId));
      }
      if (scoped.contains(contentItemId)) {
        (consumedScoped[t.productId] ??= <String>{}).add(contentItemId);
        continue;
      }

      final product = productsMap[t.productId];
      final productTitle = product?.title ?? t.productId;
      final topicId = product?.topicId ?? '';

      final title =
          t.item.anchorGroup.isNotEmpty ? t.item.anchorGroup : productTitle;
      final subtitle =
          'L1｜${t.item.intent}｜◆${t.item.difficulty}｜Day ${t.item.pushOrder}/365';
      final body = '$subtitle\n${t.item.content}';

      final payload = {
        'type': 'bubble',
        'uid': uid,
        'productId': t.productId,
        'contentItemId': t.item.id,
        // ✅ 加入 topicId 和 pushOrder，供 LearningProgressService 使用
        'topicId': topicId,
        'contentId': t.item.id, // 兼容性：contentId 和 contentItemId 都提供
        'pushOrder': t.item.pushOrder,
      };

      try {
        final notificationId = idSeed++;
        await ns.schedule(
          id: notificationId,
          when: t.when,
          title: title,
          body: body,
          payload: payload,
        );

        // ✅ 排程成功後，同步寫入兩個快取
        // 1. NotificationInboxStore（收件匣）
        await NotificationInboxStore.upsertScheduled(
          uid: uid,
          productId: t.productId,
          contentItemId: t.item.id,
          when: t.when,
          title: title,
          body: body,
        );
        
        // 2. ScheduledPushCache（排程快取，用於時間表顯示，保存 notificationId）
        await cache.add(ScheduledPushEntry(
          when: t.when,
          title: title,
          body: body,
          payload: payload,
          notificationId: notificationId,
        ));

        // ✅ 推播到最後一則時：排程「已完成 XXX 產品的學習，恭喜！」通知（每產品一次）
        if (t.isLastInProduct && !completionScheduledForProduct.contains(t.productId)) {
          completionScheduledForProduct.add(t.productId);
          final completionWhen = t.when.add(const Duration(minutes: 1));
          const completionTitle = '學習完成';
          final completionBody = '已完成 $productTitle 的學習，恭喜！';
          try {
            final completionNotificationId = idSeed++;
            await ns.schedule(
              id: completionNotificationId,
              when: completionWhen,
              title: completionTitle,
              body: completionBody,
              payload: {
                'type': 'completion',
                'uid': uid,
                'productId': t.productId,
              },
            );
            await cache.add(ScheduledPushEntry(
              when: completionWhen,
              title: completionTitle,
              body: completionBody,
              payload: {'type': 'completion', 'productId': t.productId},
              notificationId: completionNotificationId,
            ));
          } catch (e) {
            if (kDebugMode) {
              debugPrint('❌ 完成通知排程失敗 (${t.productId}): $e');
            }
          }
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('❌ 排程失敗 (${t.productId} ${t.when}): $e');
          debugPrint('Stack trace: $stackTrace');
        }
        // 繼續處理下一個，不中斷整個流程
        continue;
      }
    }

    // ✅ 只有在 reschedule 完成後，才消耗 skip
    if (consumedGlobal.isNotEmpty) {
      await SkipNextStore.removeMany(uid, consumedGlobal);
    }
    for (final entry in consumedScoped.entries) {
      await SkipNextStore.removeManyForProduct(uid, entry.key, entry.value);
    }

    // ✅ 刷新所有相關的 provider
    ref.invalidate(scheduledCacheProvider);
    ref.invalidate(upcomingTimelineProvider);

    return RescheduleResult(
      overCap: overCap,
      totalEffectiveFreq: totalEffectiveFreq,
      dailyCap: dailyCap,
      scheduledCount: tasks.length,
    );
  }
}
