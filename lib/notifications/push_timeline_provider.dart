import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bubble_library/models/content_item.dart';
import '../bubble_library/models/global_push_settings.dart';
import '../bubble_library/models/user_library.dart';
import '../bubble_library/notifications/push_scheduler.dart';
import '../bubble_library/providers/providers.dart';
import 'skip_next_store.dart';

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
  final skipSet = await SkipNextStore.load(uid);

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

  final tasks = PushScheduler.buildSchedule(
    now: DateTime.now(),
    days: 3,
    global: global,
    libraryByProductId: libMap,
    contentByProduct: contentByProduct,
    savedMap: savedMap,
    iosSafeMaxScheduled: 60,
  );

  // ✅ UI 顯示也要排除 skip（但不 remove，真正 reschedule 才 remove）
  final filtered = tasks.where((t) => !skipSet.contains(t.item.id)).toList()
    ..sort((a, b) => a.when.compareTo(b.when));

  return filtered;
});
