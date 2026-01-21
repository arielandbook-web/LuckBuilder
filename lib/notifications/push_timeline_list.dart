import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bubble_library/providers/providers.dart';
import '../bubble_library/notifications/push_orchestrator.dart';
import '../notifications/skip_next_store.dart';
import '../notifications/push_timeline_provider.dart';
import '../bubble_library/ui/product_library_page.dart';

import 'timeline_meta_mode.dart';
import 'widgets/timeline_widgets.dart';
import 'widgets/push_hint.dart';

class PushTimelineList extends ConsumerWidget {
  final bool showTopBar; // Sheet 用 false, Page 用 true
  final VoidCallback? onClose;

  const PushTimelineList({
    super.key,
    this.showTopBar = false,
    this.onClose,
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const Spacer(),
            SegmentedButton<TimelineMetaMode>(
              segments: const [
                ButtonSegment(value: TimelineMetaMode.day, label: Text('Day')),
                ButtonSegment(value: TimelineMetaMode.push, label: Text('推播')),
                ButtonSegment(value: TimelineMetaMode.nth, label: Text('第N')),
              ],
              selected: {metaMode},
              onSelectionChanged: (s) =>
                  ref.read(timelineMetaModeProvider.notifier).state = s.first,
              showSelectedIcon: false,
            ),
            const SizedBox(width: 8),
            IconButton(
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

    // Sheet 用的 header（有把手 + 關閉）
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
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const Spacer(),
                SegmentedButton<TimelineMetaMode>(
                  segments: const [
                    ButtonSegment(value: TimelineMetaMode.day, label: Text('Day')),
                    ButtonSegment(value: TimelineMetaMode.push, label: Text('推播')),
                    ButtonSegment(value: TimelineMetaMode.nth, label: Text('第N')),
                  ],
                  selected: {metaMode},
                  onSelectionChanged: (s) => ref
                      .read(timelineMetaModeProvider.notifier)
                      .state = s.first,
                  showSelectedIcon: false,
                ),
                const SizedBox(width: 6),
                IconButton(
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
                    final grouped = <String, List<dynamic>>{};
                    for (final t in items) {
                      final when = (t as dynamic).when as DateTime;
                      final dk = tlDayKey(when);
                      grouped.putIfAbsent(dk, () => []).add(t);
                    }

                    final dayKeys = grouped.keys.toList()..sort();
                    for (final dk in dayKeys) {
                      rows.add(TLRow.header(dk));

                      final list = grouped[dk]!..sort((a, b) {
                        final wa = (a as dynamic).when as DateTime;
                        final wb = (b as dynamic).when as DateTime;
                        return wa.compareTo(wb);
                      });

                      // 計算同日同商品的第N則
                      final perProdCounter = <String, int>{};
                      for (final t in list) {
                        final pid = (t as dynamic).productId as String;
                        final n = (perProdCounter[pid] ?? 0) + 1;
                        perProdCounter[pid] = n;
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
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
                                  child: Text(
                                    r.dayKey!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white.withValues(alpha: 0.85),
                                    ),
                                  ),
                                );
                              }

                              final t = r.item!;
                              final when = (t as dynamic).when as DateTime;
                              final productId = (t as dynamic).productId as String;
                              final item = (t as dynamic).item;
                              final contentItemId = (item as dynamic).id as String;
                              final preview = (item as dynamic).content as String? ?? '';
                              final day = (item as dynamic).pushOrder as int?;

                              final productTitle = productsMap[productId]?.title ?? productId;
                              final lp = libMap[productId];

                              String metaText() {
                                switch (metaMode) {
                                  case TimelineMetaMode.day:
                                    return day != null ? 'Day $day' : '';
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
                                trailing: Row(
                                  children: [
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.visibility),
                                      label: const Text('補看'),
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
                                    const SizedBox(width: 10),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.skip_next),
                                      label: const Text('跳過下一則'),
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
