import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bubble_library/providers/providers.dart';
import '../bubble_library/notifications/push_orchestrator.dart';
import '../bubble_library/notifications/push_scheduler.dart';
import '../notifications/skip_next_store.dart';
import '../notifications/push_timeline_provider.dart';
import '../bubble_library/ui/product_library_page.dart';

import 'timeline_meta_mode.dart';
import 'widgets/timeline_widgets.dart';
import 'widgets/push_hint.dart';

class PushTimelineList extends ConsumerWidget {
  final bool showTopBar; // Sheet 用 false, Page 用 true
  final VoidCallback? onClose;
  final int? limit; // 限制顯示數量（null = 全部）
  final bool dense; // 緊湊模式（用於預覽）

  const PushTimelineList({
    super.key,
    this.showTopBar = false,
    this.onClose,
    this.limit,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String uid;
    try {
      uid = ref.read(uidProvider);
    } catch (_) {
      return const Center(child: Text('請先登入'));
    }

    final metaMode = ref.watch(timelineMetaModeProvider);

    final timelineAsync = ref.watch(upcomingTimelineProvider);
    final productsAsync = ref.watch(productsMapProvider);
    final libAsync = ref.watch(libraryProductsProvider);
    final savedAsync = ref.watch(savedItemsProvider);

    Widget topBar() {
      if (!showTopBar) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Row(
          children: [
            const Text('未來 3 天時間表',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<TimelineMetaMode>(
                  segments: const [
                    ButtonSegment(
                      value: TimelineMetaMode.day,
                      label: Text('Day', style: TextStyle(fontSize: 11)),
                    ),
                    ButtonSegment(
                      value: TimelineMetaMode.push,
                      label: Text('推播', style: TextStyle(fontSize: 11)),
                    ),
                    ButtonSegment(
                      value: TimelineMetaMode.nth,
                      label: Text('第N', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                  selected: {metaMode},
                  onSelectionChanged: (s) =>
                      ref.read(timelineMetaModeProvider.notifier).state = s.first,
                  showSelectedIcon: false,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              iconSize: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: '重排未來 3 天',
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
                ref.invalidate(upcomingTimelineProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已重排未來 3 天推播')),
                  );
                }
              },
            ),
          ],
        ),
      );
    }

    Widget sheetHeader() {
      if (showTopBar) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('未來 3 天時間表',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<TimelineMetaMode>(
                      segments: const [
                        ButtonSegment(
                          value: TimelineMetaMode.day,
                          label: Text('Day', style: TextStyle(fontSize: 11)),
                        ),
                        ButtonSegment(
                          value: TimelineMetaMode.push,
                          label: Text('推播', style: TextStyle(fontSize: 11)),
                        ),
                        ButtonSegment(
                          value: TimelineMetaMode.nth,
                          label: Text('第N', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                      selected: {metaMode},
                      onSelectionChanged: (s) => ref
                          .read(timelineMetaModeProvider.notifier)
                          .state = s.first,
                      showSelectedIcon: false,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '重排',
                  icon: const Icon(Icons.refresh),
                  onPressed: () async {
                    await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
                    ref.invalidate(upcomingTimelineProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已重排未來 3 天推播')),
                      );
                    }
                  },
                ),
                IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '關閉',
                  icon: const Icon(Icons.close),
                  onPressed: onClose ?? () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return productsAsync.when(
      data: (productsMap) {
        return libAsync.when(
          data: (lib) {
            final libMap = <String, dynamic>{};
            for (final lp in lib) {
              libMap[lp.productId] = lp;
            }

            return savedAsync.when(
              data: (savedMap) {
                return timelineAsync.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return Column(
                        children: [
                          if (showTopBar) topBar() else sheetHeader(),
                          const Expanded(child: Center(child: Text('目前沒有已排程的推播'))),
                        ],
                      );
                    }

                    // build rows (header + items)
                    final rows = <TLRow>[];
                    final grouped = <String, List<PushTask>>{};
                    
                    // 如果有限制，先限制 items
                    final itemsToProcess = limit != null && limit! > 0
                        ? items.take(limit!).toList()
                        : items;
                    
                    for (final t in itemsToProcess) {
                      final dk = tlDayKey(t.when);
                      grouped.putIfAbsent(dk, () => []).add(t);
                    }

                    final dayKeys = grouped.keys.toList()..sort();
                    for (final dk in dayKeys) {
                      rows.add(TLRow.header(dk));

                      final list = grouped[dk]!..sort((a, b) {
                        return a.when.compareTo(b.when);
                      });

                      // 計算同日同商品的第N則
                      final perProdCounter = <String, int>{};
                      for (final t in list) {
                        final n = (perProdCounter[t.productId] ?? 0) + 1;
                        perProdCounter[t.productId] = n;
                        rows.add(TLRow.item(t, seqInDayForProduct: n));
                      }
                    }

                    return Column(
                      children: [
                        if (showTopBar) topBar() else sheetHeader(),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            itemCount: rows.length,
                            itemBuilder: (context, i) {
                              final r = rows[i];
                              if (r.isHeader) {
                                if (dense) {
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(0, 6, 0, 8),
                                    child: Text(
                                      r.dayKey ?? '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white.withValues(alpha: 0.75),
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                } else {
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
                                    child: Text(
                                      r.dayKey ?? '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white.withValues(alpha: 0.85),
                                      ),
                                    ),
                                  );
                                }
                              }

                              if (r.item == null) {
                                return const SizedBox.shrink();
                              }
                              final task = r.item as PushTask;
                              final when = task.when;
                              final productId = task.productId;
                              final contentItemId = task.item.id;
                              final preview = task.item.content;
                              final day = task.item.pushOrder;

                              final productTitle = productsMap[productId]?.title ?? productId;
                              final lp = libMap[productId];

                              String metaText() {
                                switch (metaMode) {
                                  case TimelineMetaMode.day:
                                    return day > 0 ? 'Day $day' : '';
                                  case TimelineMetaMode.push:
                                    return lp != null ? pushHintFor(lp) : '';
                                  case TimelineMetaMode.nth:
                                    return r.seqInDayForProduct != null
                                        ? '第 ${r.seqInDayForProduct} 則'
                                        : '';
                                }
                              }

                              final saved = savedMap[contentItemId];

                              // 判斷「同一天內第一/最後」做線條收尾（簡單判斷：前後是不是 header）
                              final prevIsHeader = i == 0 ? true : rows[i - 1].isHeader;
                              final nextIsHeader =
                                  i == rows.length - 1 ? true : rows[i + 1].isHeader;

                              return tlTimelineRow(
                                context: context,
                                when: when,
                                title: productTitle,
                                preview: preview,
                                metaText: metaText(),
                                saved: saved,
                                seqInDay: r.seqInDayForProduct,
                                isFirst: prevIsHeader,
                                isLast: nextIsHeader,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ProductLibraryPage(
                                        productId: productId,
                                        isWishlistPreview: false,
                                        initialContentItemId: contentItemId,
                                      ),
                                    ),
                                  );
                                },
                                trailing: dense
                                    ? null // 緊湊模式不顯示 trailing
                                    : Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.visibility, size: 16),
                                            label: const Text('補看'),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                            ),
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => ProductLibraryPage(
                                                    productId: productId,
                                                    isWishlistPreview: false,
                                                    initialContentItemId: contentItemId,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.skip_next, size: 16),
                                            label: const Text('跳過'),
                                            style: ElevatedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                            ),
                                            onPressed: () async {
                                              await SkipNextStore.add(uid, contentItemId);
                                              await PushOrchestrator.rescheduleNextDays(
                                                  ref: ref, days: 3);
                                              ref.invalidate(upcomingTimelineProvider);
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('已跳過下一則並重排')),
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => Column(
                    children: [
                      if (showTopBar) topBar() else sheetHeader(),
                      const Expanded(child: Center(child: CircularProgressIndicator())),
                    ],
                  ),
                  error: (e, _) => Center(child: Text('timeline error: $e')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('saved error: $e')),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('library error: $e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('products error: $e')),
    );
  }
}
