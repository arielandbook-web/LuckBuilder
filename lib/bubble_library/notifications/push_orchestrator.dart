import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/global_push_settings.dart';
import '../models/user_library.dart';
import '../providers/providers.dart';
import 'notification_service.dart';
import 'push_scheduler.dart';
import '../../notifications/daily_routine_store.dart';
import '../../notifications/dnd_settings.dart';
import '../../notifications/push_skip_store.dart';

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
  static Future<void> rescheduleNextDays({
    required WidgetRef ref,
    int days = 3,
  }) async {
    // 未登入會 throw，這是刻意的：你只要在登入後觸發一次即可
    final uid = ref.read(uidProvider);
    final dnd = await DndSettingsStore.load(uid);

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

    // 建 library map（只保留存在的 product）
    var libMap = <String, UserLibraryProduct>{};
    for (final p in lib) {
      if (!productsMap.containsKey(p.productId)) continue;
      libMap[p.productId] = p;
    }

    // 套用「日常順序」：把日常商品放在 map 前面（Dart Map 會保留 insertion order）
    final routine = await DailyRoutineStore.load(uid);
    if (routine.orderedProductIds.isNotEmpty) {
      final ordered = <String, UserLibraryProduct>{};
      for (final pid in routine.orderedProductIds) {
        final lp = libMap[pid];
        if (lp != null) ordered[pid] = lp;
      }
      for (final e in libMap.entries) {
        if (!ordered.containsKey(e.key)) ordered[e.key] = e.value;
      }
      libMap = ordered;
    }

    // 讀取 skip 並只抓推播中的 products content（效率好）
    final skipAll = await PushSkipStore.getAll(uid);

    final contentByProduct = <String, List<dynamic>>{};
    for (final entry in libMap.entries) {
      if (!entry.value.pushEnabled || entry.value.isHidden) continue;

      final list = await ref.read(contentByProductProvider(entry.key).future);

      final skipSet = (skipAll[entry.key] ?? {}).keys.toSet();
      final filtered = list.where((it) {
        try {
          final id = (it as dynamic).id?.toString();
          if (id == null) return true;
          return !skipSet.contains(id);
        } catch (_) {
          return true;
        }
      }).toList();

      contentByProduct[entry.key] = filtered;
    }

    final tasks = PushScheduler.buildSchedule(
      now: DateTime.now(),
      days: days,
      global: global,
      libraryByProductId: libMap,
      contentByProduct: contentByProduct.map((k, v) => MapEntry(k, v.cast())),
      savedMap: savedMap,
      iosSafeMaxScheduled: 60,
    );

    final ns = NotificationService();
    await ns.cancelAll();

    int idSeed = DateTime.now().millisecondsSinceEpoch.remainder(1000000);
    DateTime? prevWhen;

    for (final t in tasks) {
      final scheduledAt = adjustWhen(
        original: t.when,
        s: dnd,
        prev: prevWhen,
      );
      prevWhen = scheduledAt;

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
        when: scheduledAt,
        title: title,
        body: body,
        payload: payload,
      );
    }
  }
}
