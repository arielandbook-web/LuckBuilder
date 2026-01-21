import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bubble_library/providers/providers.dart';
import '../bubble_library/notifications/push_orchestrator.dart';
import '../notifications/skip_next_store.dart';
import '../notifications/push_timeline_provider.dart';
import '../bubble_library/ui/product_library_page.dart';
import '../bubble_library/ui/push_product_config_page.dart';
import '../notifications/timeline_meta_mode.dart';
import '../notifications/widgets/timeline_widgets.dart';
import '../notifications/widgets/push_hint.dart';

class PushTimelinePage extends ConsumerWidget {
  const PushTimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String uid;
    try {
      uid = ref.read(uidProvider);
    } catch (_) {
      return const Scaffold(body: Center(child: Text('請先登入')));
    }

    final timelineAsync = ref.watch(upcomingTimelineProvider);
    final productsAsync = ref.watch(productsMapProvider);
    final savedAsync = ref.watch(savedItemsProvider);
    final libAsync = ref.watch(libraryProductsProvider);

    final metaMode = ref.watch(timelineMetaModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('未來 3 天時間表'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<TimelineMetaMode>(
              segments: const [
                ButtonSegment(value: TimelineMetaMode.day, label: Text('Day')),
                ButtonSegment(
                    value: TimelineMetaMode.push, label: Text('推播')),
                ButtonSegment(value: TimelineMetaMode.nth, label: Text('第N')),
              ],
              selected: {metaMode},
              onSelectionChanged: (s) =>
                  ref.read(timelineMetaModeProvider.notifier).state = s.first,
              showSelectedIcon: false,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重排未來 3 天',
            onPressed: () async {
              await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
              ref.invalidate(upcomingTimelineProvider);
              // ignore: use_build_context_synchronously
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已重排未來 3 天推播')),
              );
            },
          ),
        ],
      ),
      body: productsAsync.when(
        data: (productsMap) {
          return savedAsync.when(
            data: (savedMap) {
              return libAsync.when(
                data: (lib) {
                  final libMap = {for (final lp in lib) lp.productId: lp};

                  return timelineAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(child: Text('目前沒有已排程的推播'));
                  }

                  // ✅ 分組：yyyy-mm-dd -> List<PushTask>
                  final groups = <String, List<dynamic>>{};
                  for (final t in items) {
                    final when = (t as dynamic).when as DateTime;
                    final key = tlDayKey(when);
                    groups.putIfAbsent(key, () => []).add(t);
                  }

                  final dayKeys = groups.keys.toList()..sort();
                  final rows = <TLRow>[];

                  for (final dk in dayKeys) {
                    rows.add(TLRow.header(dk));

                    final list = groups[dk]!..sort((a, b) {
                      final wa = (a as dynamic).when as DateTime;
                      final wb = (b as dynamic).when as DateTime;
                      return wa.compareTo(wb);
                    });

                    // ✅ 計數：同一天內，每個 product 的第幾則
                    final cntByProduct = <String, int>{};

                    for (final t in list) {
                      final pid = (t as dynamic).productId as String;
                      final next = (cntByProduct[pid] ?? 0) + 1;
                      cntByProduct[pid] = next;

                      rows.add(TLRow.item(t, seqInDayForProduct: next));
                    }
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final r = rows[index];
                      if (r.isHeader) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 10),
                          child: _DayHeader(title: _dayTitle(r.dayKey!)),
                        );
                      }

                      final seqInDayForProduct = r.seqInDayForProduct;
                      final it = r.item!;

                      final when = (it as dynamic).when as DateTime;
                      final productId = (it as dynamic).productId as String;
                      final item = (it as dynamic).item;
                      final contentItemId = (item as dynamic).id as String;
                      final preview = (item as dynamic).content as String?;
                      final day = (item as dynamic).pushOrder; // Day 1..365

                      final saved = savedMap[contentItemId];
                      final productTitle = productsMap[productId]?.title ?? productId;
                      final lp = libMap[productId];

                      String metaText() {
                        switch (metaMode) {
                          case TimelineMetaMode.day:
                            return day != null ? 'Day $day' : '';
                          case TimelineMetaMode.push:
                            return lp != null ? pushHintFor(lp) : '';
                          case TimelineMetaMode.nth:
                            return seqInDayForProduct != null
                                ? '第 $seqInDayForProduct 則'
                                : '';
                        }
                      }

                      final isFirstItemOfDay = index > 0 && rows[index - 1].isHeader;
                      final isLastItemOfDay =
                          (index + 1 >= rows.length) || rows[index + 1].isHeader;

                      return tlTimelineRow(
                        context: context,
                        when: when,
                        title: productTitle,
                        preview: preview ?? '',
                        metaText: metaText(),
                        saved: saved,
                        seqInDay: seqInDayForProduct,
                        isFirst: isFirstItemOfDay,
                        isLast: isLastItemOfDay,
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
                            OutlinedButton.icon(
                              icon: const Icon(Icons.tune),
                              label: const Text('設定'),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PushProductConfigPage(
                                        productId: productId),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.skip_next),
                              label: const Text('跳過此商品下一則'),
                              onPressed: () async {
                                await SkipNextStore.addProductScoped(
                                    uid, productId, contentItemId);
                                await PushOrchestrator.rescheduleNextDays(
                                    ref: ref, days: 3);
                                ref.invalidate(upcomingTimelineProvider);

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('已跳過此商品下一則並重排')),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('timeline error: $e')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('library error: $e')),
            );
          },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('saved error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('products error: $e')),
      ),
    );
  }


  String _dayTitle(String dayKey) {
    // dayKey: yyyy-mm-dd
    final parts = dayKey.split('-');
    if (parts.length != 3) return dayKey;
    final y = parts[0];
    final m = parts[1];
    final d = parts[2];
    return '$m/$d · $y';
  }


}

class _DayHeader extends StatelessWidget {
  final String title;
  const _DayHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white.withValues(alpha: 0.10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
      ],
    );
  }
}


