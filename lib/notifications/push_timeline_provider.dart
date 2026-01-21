import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bubble_library/models/content_item.dart';
import '../bubble_library/models/global_push_settings.dart';
import '../bubble_library/models/user_library.dart';
import '../bubble_library/notifications/push_scheduler.dart';
import '../bubble_library/providers/providers.dart';
import 'daily_routine_store.dart';
import 'dnd_settings.dart';
import 'push_skip_store.dart';

/// 未來 N 天推播時間表（真資料）
/// - 使用 PushScheduler.buildSchedule（與實際排程同邏輯）
/// - 套用 skip store（略過被跳過的 contentItemId）
/// 回傳 List<dynamic> 以避免你專案 task 型別名稱不一致造成編譯問題
final upcomingTimelineProvider =
    FutureProvider.autoDispose<List<dynamic>>((ref) async {
  String uid;
  try {
    uid = ref.read(uidProvider);
  } catch (_) {
    return [];
  }

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

  // 讀取 skip map
  final skipAll = await PushSkipStore.getAll(uid);

  // 只保留存在的 product
  var libMap = <String, UserLibraryProduct>{};
  for (final p in lib) {
    if (!productsMap.containsKey(p.productId)) continue;
    libMap[p.productId] = p;
  }

  // 套用「日常順序」：與 orchestrator 一致
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

  // 只抓推播中的 products content
  final contentByProduct = <String, List<ContentItem>>{};
  for (final entry in libMap.entries) {
    final lp = entry.value;
    if (!lp.pushEnabled || lp.isHidden) continue;

    final list = await ref.read(contentByProductProvider(entry.key).future);

    // 套用 skip：略過被標記的 contentItemId
    final skipSet = (skipAll[entry.key] ?? {}).keys.toSet();
    final filtered = list.where((it) {
      try {
        final id = it.id;
        if (id.isEmpty) return true;
        return !skipSet.contains(id);
      } catch (_) {
        return true;
      }
    }).toList();

    contentByProduct[entry.key] = filtered;
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

  final dnd = await DndSettingsStore.load(uid);
  DateTime? prev;
  final out = <dynamic>[];

  for (final t in tasks) {
    final adjusted = adjustWhen(
      original: (t as dynamic).when as DateTime,
      s: dnd,
      prev: prev,
    );
    prev = adjusted;
    out.add(_TimelineEntry(
      when: adjusted,
      productId: (t as dynamic).productId.toString(),
      item: (t as dynamic).item,
    ));
  }

  return out;
});

class _TimelineEntry {
  final DateTime when;
  final String productId;
  final dynamic item;
  _TimelineEntry(
      {required this.when, required this.productId, required this.item});
}
