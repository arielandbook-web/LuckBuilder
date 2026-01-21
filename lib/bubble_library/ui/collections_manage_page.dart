import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collections/collections_controller.dart';
import '../collections/daily_routine_provider.dart';
import '../collections/collections_store.dart';
import '../models/user_library.dart';
import '../notifications/push_orchestrator.dart';
import '../providers/providers.dart';
import '../../notifications/daily_routine_store.dart';
import '../../notifications/push_timeline_provider.dart';
import 'collection_detail_page.dart';
import 'daily_routine_order_page.dart';

class CollectionsManagePage extends ConsumerWidget {
  const CollectionsManagePage({super.key});

  Future<void> _promptCreate(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('新增收藏集'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: '例如：睡前 10 分鐘 / 通勤碎片'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('建立')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(collectionsControllerProvider.notifier).create(c.text);
    }
  }

  Future<void> _promptRename(
      BuildContext context, WidgetRef ref, BubbleCollection col) async {
    final c = TextEditingController(text: col.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重新命名'),
        content: TextField(controller: c),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存')),
        ],
      ),
    );
    if (ok == true) {
      await ref
          .read(collectionsControllerProvider.notifier)
          .rename(col.id, c.text);
    }
  }

  Future<void> _promptPreset(
      BuildContext context, WidgetRef ref, BubbleCollection col) async {
    int? freq = col.presetFreqPerDay;
    String? mode = col.presetTimeMode;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('推播模板（本機）'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: freq,
                decoration: const InputDecoration(labelText: '每日幾則'),
                items: const [1, 2, 3, 5, 8]
                    .map((e) =>
                        DropdownMenuItem(value: e, child: Text('$e 則/天')))
                    .toList(),
                onChanged: (v) => setLocal(() => freq = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: mode,
                decoration:
                    const InputDecoration(labelText: '模式（timeMode.name）'),
                items: const ['fixed', 'smart', 'morning', 'evening']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setLocal(() => mode = v),
              ),
              const SizedBox(height: 10),
              const Text(
                '先存本機，之後你要「一鍵套用到推播設定」再接 repo 寫入。',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('保存')),
          ],
        ),
      ),
    );

    if (ok == true) {
      await ref.read(collectionsControllerProvider.notifier).setPreset(
            collectionId: col.id,
            freqPerDay: freq,
            timeModeName: mode,
          );
    }
  }

  Future<void> _applyPresetToCollection(
    BuildContext context,
    WidgetRef ref,
    BubbleCollection col,
  ) async {
    if (col.presetFreqPerDay == null && col.presetTimeMode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('此收藏集尚未設定推播模板')),
      );
      return;
    }

    final uid = ref.read(uidProvider);
    final repo = ref.read(libraryRepoProvider);

    final lib = await ref.read(libraryProductsProvider.future);
    final byPid = <String, UserLibraryProduct>{
      for (final lp in lib) lp.productId: lp,
    };

    int applied = 0;
    int skipped = 0;
    int failed = 0;

    for (final pid in col.productIds) {
      final lp = byPid[pid];
      if (lp == null) {
        skipped++;
        continue;
      }
      try {
        await repo.setPushEnabled(uid, pid, true);

        final m = lp.pushConfig.toMap();
        if (col.presetFreqPerDay != null) {
          m['freqPerDay'] = col.presetFreqPerDay;
        }
        if (col.presetTimeMode != null) {
          m['timeMode'] = col.presetTimeMode;
        }

        await repo.setPushConfig(uid, pid, m);

        applied++;
      } catch (_) {
        failed++;
      }
    }

    await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
    ref.invalidate(upcomingTimelineProvider);

    // ignore: use_build_context_synchronously
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('已套用模板：成功 $applied、跳過(未購買) $skipped、失敗 $failed')),
      );
    }
  }

  Future<void> _makeCollectionDaily(
    BuildContext context,
    WidgetRef ref,
    BubbleCollection col,
  ) async {
    final uid = ref.read(uidProvider);
    final repo = ref.read(libraryRepoProvider);

    final lib = await ref.read(libraryProductsProvider.future);
    final byPid = <String, UserLibraryProduct>{
      for (final lp in lib) lp.productId: lp,
    };

    final purchasedInOrder = <String>[];
    int applied = 0, skipped = 0, failed = 0;

    for (final pid in col.productIds) {
      final lp = byPid[pid];
      if (lp == null) {
        skipped++;
        continue;
      }

      purchasedInOrder.add(pid);

      try {
        if (col.presetFreqPerDay != null || col.presetTimeMode != null) {
          await repo.setPushEnabled(uid, pid, true);

          final m = lp.pushConfig.toMap();
          if (col.presetFreqPerDay != null) {
            m['freqPerDay'] = col.presetFreqPerDay;
          }
          if (col.presetTimeMode != null) {
            m['timeMode'] = col.presetTimeMode;
          }
          await repo.setPushConfig(uid, pid, m);
        }
        applied++;
      } catch (_) {
        failed++;
      }
    }

    if (purchasedInOrder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('此收藏集內沒有已購買商品，無法設為日常')),
      );
      return;
    }

    await DailyRoutineStore.save(
      uid,
      DailyRoutine(
        activeCollectionId: col.id,
        orderedProductIds: purchasedInOrder,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
    ref.invalidate(upcomingTimelineProvider);
    ref.invalidate(dailyRoutineProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('已設為日常：成功 $applied、跳過(未購買) $skipped、失敗 $failed')),
      );
    }
  }

  Future<void> _clearDaily(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(uidProvider);
    await DailyRoutineStore.clear(uid);

    await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
    ref.invalidate(upcomingTimelineProvider);
    ref.invalidate(dailyRoutineProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已取消日常，並重排未來 3 天推播')),
      );
    }
  }

  Widget _buildTrailingForCollection(
    BuildContext context,
    WidgetRef ref,
    BubbleCollection c,
    DailyRoutine routine,
  ) {
    final isDaily = (routine.activeCollectionId ?? '').isNotEmpty &&
        routine.activeCollectionId == c.id;
    return PopupMenuButton<String>(
      onSelected: (k) async {
        if (k == 'rename') {
          await _promptRename(context, ref, c);
        }
        // ignore: use_build_context_synchronously
        if (k == 'preset') {
          await _promptPreset(context, ref, c);
        }
        if (k == 'apply') {
          await _applyPresetToCollection(context, ref, c);
        }
        if (k == 'daily') {
          await _makeCollectionDaily(context, ref, c);
        }
        if (k == 'daily_off') {
          await _clearDaily(context, ref);
        }
        if (k == 'delete') {
          await ref.read(collectionsControllerProvider.notifier).remove(c.id);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'rename', child: Text('重新命名')),
        const PopupMenuItem(value: 'preset', child: Text('推播模板')),
        if ((c.presetFreqPerDay != null || c.presetTimeMode != null) &&
            c.productIds.isNotEmpty)
          const PopupMenuItem(value: 'apply', child: Text('套用模板到全部（已購買）')),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'daily',
          child: Text(isDaily ? '日常中（重新套用/重排）' : '把收藏集變成日常'),
        ),
        if (isDaily)
          const PopupMenuItem(value: 'daily_off', child: Text('取消此收藏集日常')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'delete', child: Text('刪除')),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(collectionsControllerProvider);
    final routineAsync = ref.watch(dailyRoutineProvider);
    final libAsync = ref.watch(libraryProductsProvider);
    final productsMapAsync = ref.watch(productsMapProvider);
    final timelineAsync = ref.watch(upcomingTimelineProvider);
    final activeId = routineAsync.value?.activeCollectionId;
    final hasDaily = activeId != null && activeId.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('收藏集管理'),
        actions: [
          if (hasDaily)
            IconButton(
              tooltip: '調整日常順序',
              icon: const Icon(Icons.swap_vert),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const DailyRoutineOrderPage()),
              ),
            ),
          if (hasDaily)
            IconButton(
              tooltip: '取消日常',
              icon: const Icon(Icons.pause_circle_outline),
              onPressed: () => _clearDaily(context, ref),
            ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _promptCreate(context, ref),
          ),
        ],
      ),
      body: async.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('尚未建立收藏集，右上角＋新增'));
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _LibraryOverviewCard(
                collectionsAsync: async.whenData((l) => l.cast<dynamic>()),
                routineAsync: routineAsync,
                libAsync: libAsync.whenData((l) => l.cast<dynamic>()),
                timelineAsync: timelineAsync,
                onOpenDailyOrder: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const DailyRoutineOrderPage()),
                  );
                },
                onClearDaily: () => _clearDaily(context, ref),
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < list.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                productsMapAsync.when(
                  data: (productsMap) {
                    return libAsync.when(
                      data: (lib) {
                        return routineAsync.when(
                          data: (routine) {
                            final purchasedSet = <String>{};
                            final pushingSet = <String>{};
                            for (final lp in lib) {
                              purchasedSet.add(lp.productId);
                              if (lp.pushEnabled) pushingSet.add(lp.productId);
                            }
                            final c = list[i];
                            final ids = (c.productIds as List)
                                .map((e) => e.toString())
                                .toList();
                            final total = ids.length;
                            final purchased =
                                ids.where(purchasedSet.contains).length;
                            final pushing =
                                ids.where(pushingSet.contains).length;
                            final activeCid =
                                (routine.activeCollectionId ?? '').toString();
                            final isDaily =
                                activeCid.isNotEmpty && activeCid == c.id;
                            final previewTitles = <String>[];
                            for (final pid in ids.take(3)) {
                              final p = productsMap[pid];
                              if (p != null) previewTitles.add(p.title);
                            }
                            return _CollectionDenseCard(
                              name: c.name,
                              isDaily: isDaily,
                              total: total,
                              purchased: purchased,
                              pushing: pushing,
                              previewTitles: previewTitles,
                              onTap: () {
                                final ids = (c.productIds as List)
                                    .map((e) => e.toString())
                                    .toList();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CollectionDetailPage(
                                      collectionId: c.id,
                                      collectionName: c.name,
                                      productIds: ids,
                                    ),
                                  ),
                                );
                              },
                              trailing: _buildTrailingForCollection(
                                  context, ref, c, routine),
                            );
                          },
                          loading: () => _CollectionDenseCard.skeleton(),
                          error: (e, _) =>
                              _CollectionDenseCard.error(name: '讀取日常狀態失敗: $e'),
                        );
                      },
                      loading: () => _CollectionDenseCard.skeleton(),
                      error: (e, _) =>
                          _CollectionDenseCard.error(name: '讀取泡泡庫失敗: $e'),
                    );
                  },
                  loading: () => _CollectionDenseCard.skeleton(),
                  error: (e, _) =>
                      _CollectionDenseCard.error(name: '讀取商品失敗: $e'),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('collections error: $e')),
      ),
    );
  }
}

class _LibraryOverviewCard extends ConsumerWidget {
  final AsyncValue<List<dynamic>> collectionsAsync;
  final AsyncValue<dynamic> routineAsync;
  final AsyncValue<List<dynamic>> libAsync;
  final AsyncValue<List<dynamic>> timelineAsync;

  final VoidCallback onOpenDailyOrder;
  final VoidCallback onClearDaily;

  const _LibraryOverviewCard({
    required this.collectionsAsync,
    required this.routineAsync,
    required this.libAsync,
    required this.timelineAsync,
    required this.onOpenDailyOrder,
    required this.onClearDaily,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1) 收藏集數量
    final collectionCount = collectionsAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => null,
    );

    // 2) 日常狀態 + 日常商品數
    final activeCollectionId = routineAsync.maybeWhen(
      data: (r) {
        try {
          return (r as dynamic).activeCollectionId?.toString();
        } catch (_) {
          return null;
        }
      },
      orElse: () => null,
    );

    final dailyProductIds = routineAsync.maybeWhen(
      data: (r) {
        try {
          final ids = (r as dynamic).orderedProductIds as List?;
          return ids?.map((e) => e.toString()).toList() ?? <String>[];
        } catch (_) {
          return <String>[];
        }
      },
      orElse: () => <String>[],
    );

    // 3) 找出日常收藏集名稱
    final activeCollectionName =
        (activeCollectionId == null || activeCollectionId.isEmpty)
            ? null
            : collectionsAsync.maybeWhen(
                data: (cols) {
                  for (final c in cols) {
                    try {
                      if ((c as dynamic).id?.toString() == activeCollectionId) {
                        return (c as dynamic).name?.toString() ?? '日常收藏集';
                      }
                    } catch (_) {}
                  }
                  return '日常收藏集';
                },
                orElse: () => '日常收藏集',
              );

    // 4) 推播中商品數（從 libraryProductsProvider）
    final pushingCount = libAsync.maybeWhen(
      data: (lib) {
        int n = 0;
        for (final lp in lib) {
          try {
            final d = lp as dynamic;
            final pushing = (d.pushEnabled as bool?) ?? false;
            final hidden = (d.isHidden as bool?) ?? false;
            if (!hidden && pushing) n++;
          } catch (_) {}
        }
        return n;
      },
      orElse: () => null,
    );

    // 5) 今日排程數 + 下一則時間（從 upcomingTimelineProvider）
    final now = DateTime.now();
    final todayCount = timelineAsync.maybeWhen(
      data: (list) {
        int n = 0;
        for (final t in list) {
          try {
            final when = (t as dynamic).when as DateTime?;
            if (when == null) continue;
            if (_isSameDay(when, now)) n++;
          } catch (_) {}
        }
        return n;
      },
      orElse: () => null,
    );

    final nextTimeText = timelineAsync.maybeWhen(
      data: (list) {
        DateTime? next;
        for (final t in list) {
          try {
            final when = (t as dynamic).when as DateTime?;
            if (when == null) continue;
            if (when.isAfter(now) && (next == null || when.isBefore(next))) {
              next = when;
            }
          } catch (_) {}
        }
        if (next == null) return null;
        return _hm(next);
      },
      orElse: () => null,
    );

    final hasDaily =
        activeCollectionId != null && activeCollectionId.isNotEmpty;

    return Card(
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 18),
                const SizedBox(width: 8),
                const Text(
                  '泡泡庫總覽',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                if (hasDaily)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: const Text('日常中',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.play_circle_outline,
                    size: 18, color: Colors.white.withValues(alpha: 0.85)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasDaily
                        ? '目前日常：${activeCollectionName ?? '（讀取中）'}'
                        : '目前未啟用日常（建議選一個收藏集變成日常）',
                    style:
                        TextStyle(color: Colors.white.withValues(alpha: 0.88)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _miniChip(
                    '收藏集', collectionCount == null ? '—' : '$collectionCount'),
                _miniChip('日常商品', '${dailyProductIds.length}'),
                _miniChip('推播中', pushingCount == null ? '—' : '$pushingCount'),
                _miniChip('今日已排', todayCount == null ? '—' : '$todayCount'),
                _miniChip('下一則', nextTimeText ?? '—'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasDaily ? onOpenDailyOrder : null,
                    icon: const Icon(Icons.swap_vert),
                    label: const Text('調整日常順序'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: hasDaily ? onClearDaily : null,
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('取消日常'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _miniChip(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        '$k $v',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.90),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CollectionDenseCard extends StatelessWidget {
  final String name;
  final bool isDaily;
  final int total;
  final int purchased;
  final int pushing;
  final List<String> previewTitles;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _CollectionDenseCard({
    required this.name,
    required this.isDaily,
    required this.total,
    required this.purchased,
    required this.pushing,
    required this.previewTitles,
    this.onTap,
    this.trailing,
  });

  factory _CollectionDenseCard.skeleton() => const _CollectionDenseCard(
        name: '載入中…',
        isDaily: false,
        total: 0,
        purchased: 0,
        pushing: 0,
        previewTitles: [],
      );

  factory _CollectionDenseCard.error({required String name}) =>
      _CollectionDenseCard(
        name: name,
        isDaily: false,
        total: 0,
        purchased: 0,
        pushing: 0,
        previewTitles: const [],
      );

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Card(
        elevation: 0,
        color: Colors.white.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (isDaily) ...[
                    const SizedBox(width: 8),
                    _badge('日常中'),
                  ],
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip('總數', '$total'),
                  _chip('已購買', '$purchased'),
                  _chip('推播中', '$pushing'),
                ],
              ),
              if (previewTitles.isNotEmpty) ...[
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: previewTitles
                      .map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• ',
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.85))),
                                Expanded(
                                  child: Text(
                                    t,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.85)),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ] else ...[
                const SizedBox(height: 12),
                Text('（此收藏集尚未加入商品）',
                    style:
                        TextStyle(color: Colors.white.withValues(alpha: 0.65))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Text(text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
      );

  static Widget _chip(String k, String v) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Text(
          '$k $v',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.90),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
