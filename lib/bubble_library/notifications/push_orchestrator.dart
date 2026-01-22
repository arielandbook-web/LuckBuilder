import 'dart:convert';
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
  static Future<void> rescheduleNextDays({
    required WidgetRef ref,
    int days = 3,
  }) async {
    final uid = ref.read(uidProvider);

    final lib = await ref.read(libraryProductsProvider.future);
    final productsMap = await ref.read(productsMapProvider.future);

    GlobalPushSettings global;
    try {
      global = await ref.read(globalPushSettingsProvider.future);
    } catch (_) {
      global = GlobalPushSettings.defaults();
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

    // ✅ 先取消全部，再依新 tasks schedule
    final ns = NotificationService();
    await ns.cancelAll();

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

      final productTitle = productsMap[t.productId]?.title ?? t.productId;

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
      };

      await ns.schedule(
        id: idSeed++,
        when: t.when,
        title: title,
        body: body,
        payload: payload,
      );

      // ✅ 排程成功就寫入 Inbox（本機真資料）
      await NotificationInboxStore.upsertScheduled(
        uid: uid,
        productId: t.productId,
        contentItemId: t.item.id,
        when: t.when,
        title: title,
        body: body,
      );
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
