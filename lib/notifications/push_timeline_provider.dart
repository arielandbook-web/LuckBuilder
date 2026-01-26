import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bubble_library/models/content_item.dart';
import '../bubble_library/models/global_push_settings.dart';
import '../bubble_library/models/user_library.dart';
import '../bubble_library/notifications/push_scheduler.dart';
import '../bubble_library/providers/providers.dart';
import '../bubble_library/notifications/scheduled_push_cache.dart';
import 'skip_next_store.dart';
import 'daily_routine_store.dart';
import 'notification_inbox_store.dart';

/// 未來 3 天推播時間表（真資料）
/// - 不會 schedule 通知（只計算）
/// - 會套用 skipSet（但不消耗 skip，一直到真正 reschedule 才消耗）
final upcomingTimelineProvider = FutureProvider<List<PushTask>>((ref) async {
  // 需要登入
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

  // ✅ 跳過下一則清單（本機）
  final globalSkip = await SkipNextStore.load(uid);
  // ✅ Missed 清單（本機）：滑掉/錯過的內容，時間表也要排除
  final missedContentItemIds = await NotificationInboxStore.loadMissedContentItemIds(uid);

  // 建 library map（只保留存在的 product）
  final libMap = <String, UserLibraryProduct>{};
  for (final p in lib) {
    if (!productsMap.containsKey(p.productId)) continue;
    libMap[p.productId] = p;
  }

  // 只抓推播中的 products content（與 Orchestrator 一樣）
  final contentByProduct = <String, List<ContentItem>>{};
  for (final entry in libMap.entries) {
    final lp = entry.value;
    if (!lp.pushEnabled || lp.isHidden) continue;
    final list = await ref.read(contentByProductProvider(entry.key).future);
    contentByProduct[entry.key] = list.cast<ContentItem>();
  }

  // ✅ 真排序：日常順序
  final routine = await DailyRoutineStore.load(uid);
  final productOrder = List<String>.from(routine.orderedProductIds);

  // ✅ order index（timeline UI 同時間要照這個排）
  final orderIdx = <String, int>{};
  for (int i = 0; i < productOrder.length; i++) {
    orderIdx[productOrder[i]] = i;
  }
  int idxOf(String pid) => orderIdx[pid] ?? (1 << 20);

  final tasks = PushScheduler.buildSchedule(
    now: DateTime.now(),
    days: 3,
    global: global,
    libraryByProductId: libMap,
    contentByProduct: contentByProduct,
    savedMap: savedMap,
    iosSafeMaxScheduled: 60,
    productOrder: productOrder,
    missedContentItemIds: missedContentItemIds,
  );

  // ✅ scoped skip 一次載入（避免每筆 await）
  final pids = tasks.map((t) => t.productId).toSet().toList();
  final scopedPairs = await Future.wait(pids.map((pid) async {
    final set = await SkipNextStore.loadForProduct(uid, pid);
    return MapEntry(pid, set);
  }));
  final scopedMap = <String, Set<String>>{
    for (final e in scopedPairs) e.key: e.value
  };

  // ✅ UI 顯示也要排除 skip（全域 + 商品範圍）
  final filtered = <PushTask>[];
  for (final t in tasks) {
    if (globalSkip.contains(t.item.id)) continue;
    final scoped = scopedMap[t.productId] ?? const <String>{};
    if (scoped.contains(t.item.id)) continue;
    filtered.add(t);
  }

  // ✅ 真排序：when 相同也要照日常順序（不洗掉）
  filtered.sort((a, b) {
    final t = a.when.compareTo(b.when);
    if (t != 0) return t;

    final ao = idxOf(a.productId);
    final bo = idxOf(b.productId);
    if (ao != bo) return ao.compareTo(bo);

    return a.productId.compareTo(b.productId);
  });

  return filtered;
});

/// 讀取本機快取的未來 3 天推播排程（公開 provider，供泡泡庫等 UI 使用；重排後需 invalidate）
final scheduledCacheProvider =
    FutureProvider<List<ScheduledPushEntry>>((ref) async {
  return ScheduledPushCache()
      .loadSortedUpcoming(horizon: const Duration(days: 3));
});
