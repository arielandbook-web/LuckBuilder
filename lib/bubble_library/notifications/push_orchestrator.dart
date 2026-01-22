import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/global_push_settings.dart';
import '../models/user_library.dart';
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
  /// 
  /// [overrideGlobal] 可選：如果提供，會優先使用此設定（用於立即更新時避免讀到舊值）
  static Future<void> rescheduleNextDays({
    required WidgetRef ref,
    int days = 3,
    GlobalPushSettings? overrideGlobal,
  }) async {
    final uid = ref.read(uidProvider);

    final lib = await ref.read(libraryProductsProvider.future);
    final productsMap = await ref.read(productsMapProvider.future);

    GlobalPushSettings global;
    if (overrideGlobal != null) {
      global = overrideGlobal;
    } else {
      try {
        global = await ref.read(globalPushSettingsProvider.future);
      } catch (_) {
        global = GlobalPushSettings.defaults();
      }
    }

    Map<String, SavedContent> savedMap;
    try {
      savedMap = await ref.read(savedItemsProvider.future);
    } catch (_) {
      savedMap = {};
    }

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
      
      final pushingProducts = libMap.values.where((p) => p.pushEnabled && !p.isHidden).toList();
      debugPrint('  - 推播中的產品: ${pushingProducts.length}');
      for (final p in pushingProducts) {
        final cfg = p.pushConfig;
        debugPrint('    • ${p.productId}:');
        debugPrint('      - pushEnabled: ${p.pushEnabled}, hidden: ${p.isHidden}');
        debugPrint('      - freq: ${cfg.freqPerDay}, timeMode: ${cfg.timeMode.name}');
        debugPrint('      - presetSlots: ${cfg.presetSlots}');
        debugPrint('      - daysOfWeek: ${cfg.daysOfWeek}');
        debugPrint('      - quietHours: ${cfg.quietHours.start.hour}:${cfg.quietHours.start.minute} - ${cfg.quietHours.end.hour}:${cfg.quietHours.end.minute}');
      }
      
      debugPrint('  - contentByProduct 數量: ${contentByProduct.length}');
      for (final entry in contentByProduct.entries) {
        debugPrint('    • ${entry.key}: ${entry.value.length} 個內容項目');
      }
    }

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
    await ns.cancelAll();
    await cache.clear(); // ✅ 同步清除快取

    int idSeed = DateTime.now().millisecondsSinceEpoch.remainder(1000000);

    // ✅ 這輪 reschedule 會消耗掉的 skip（只在 reschedule 才消耗）
    final consumedGlobal = <String>{};
    final consumedScoped = <String, Set<String>>{};

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

      await ns.schedule(
        id: idSeed++,
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
      
      // 2. ScheduledPushCache（排程快取，用於時間表顯示）
      await cache.add(ScheduledPushEntry(
        when: t.when,
        title: title,
        body: body,
        payload: payload,
      ));
    }

    // ✅ 只有在 reschedule 完成後，才消耗 skip
    if (consumedGlobal.isNotEmpty) {
      await SkipNextStore.removeMany(uid, consumedGlobal);
    }
    for (final entry in consumedScoped.entries) {
      await SkipNextStore.removeManyForProduct(uid, entry.key, entry.value);
    }
  }
}
