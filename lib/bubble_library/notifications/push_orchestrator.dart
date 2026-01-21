import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/global_push_settings.dart';
import '../models/user_library.dart';
import '../providers/providers.dart';
import 'notification_service.dart';
import 'push_scheduler.dart';
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

    // ===== Skip 下一則：在重排前先把被跳過的 contentItem 從列表移除（等於跳過一次） =====
    final skipStore = PushSkipStore();
    final consumedByProduct = <String, List<String>>{};

    for (final entry in contentByProduct.entries) {
      final productId = entry.key;
      final list = entry.value;

      final skipped = await skipStore.getSkippedIds(productId);
      if (skipped.isEmpty) continue;

      final consumed = <String>[];

      // 兼容 item 可能是 model（.id）或 map（['id']）
      list.removeWhere((item) {
        String? id;
        try {
          final dyn = item as dynamic;
          if (dyn != null) {
            final v = dyn.id;
            if (v != null) id = v.toString();
          }
        } catch (_) {}
        if (id == null && item is Map) {
          final v = item['id'];
          if (v != null) id = v.toString();
        }

        if (id == null) return false;
        if (skipped.contains(id)) {
          consumed.add(id);
          return true; // 移除 => 這次重排就會跳過它
        }
        return false;
      });

      if (consumed.isNotEmpty) {
        consumedByProduct[productId] = consumed;
      }
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

    // 已在本次重排中移除（跳過）的項目：消耗掉，避免下次一直跳同一則
    for (final e in consumedByProduct.entries) {
      await skipStore.consume(productId: e.key, consumedIds: e.value);
    }

    int idSeed = DateTime.now().millisecondsSinceEpoch.remainder(1000000);

    for (final t in tasks) {
      final productTitle = productsMap[t.productId]?.title ?? t.productId;

      // banner/展開都像「學習卡」
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
    }
  }
}
