import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bubble_library/providers/providers.dart';
import '../bubble_library/notifications/push_orchestrator.dart';
import '../bubble_library/notifications/push_scheduler.dart';
import '../notifications/skip_next_store.dart';
import '../notifications/push_timeline_provider.dart';
import '../bubble_library/ui/product_library_page.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('未來 3 天時間表'),
        actions: [
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
              return timelineAsync.when(
                data: (items) {
              if (items.isEmpty) {
                return const Center(child: Text('目前沒有已排程的推播'));
              }

              // ✅ 分組：yyyy-mm-dd -> List<PushTask>
              final groups = <String, List<PushTask>>{};
              for (final t in items) {
                final key = _dayKey(t.when);
                groups.putIfAbsent(key, () => []).add(t);
              }

              final dayKeys = groups.keys.toList()..sort(); // 依日期排序
              final rows = <_TimelineRow>[];

              for (final dk in dayKeys) {
                rows.add(_TimelineRow.header(dk));
                final list = groups[dk]!;
                list.sort((a, b) => a.when.compareTo(b.when));
                for (final t in list) {
                  rows.add(_TimelineRow.item(t));
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

                  final it = r.item!;

                  final when = it.when;
                  final productId = it.productId;
                  final contentItemId = it.item.id;
                  final preview = it.item.content;
                  final day = it.item.pushOrder;

                  final productTitle = productsMap[productId]?.title ?? productId;
                  final saved = savedMap[contentItemId];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _timeOnly(when),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900, fontSize: 13),
                                ),
                                const Spacer(),
                                Text('Day $day',
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.7))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                if ((saved?.learned ?? false))
                                  _tag('已學會', Icons.check_circle),
                                if ((saved?.favorite ?? false))
                                  _tag('收藏', Icons.star),
                                if ((saved?.reviewLater ?? false))
                                  _tag('稍後', Icons.schedule),
                              ],
                            ),
                            if ((saved?.learned ?? false) ||
                                (saved?.favorite ?? false) ||
                                (saved?.reviewLater ?? false))
                              const SizedBox(height: 8),
                            Text(
                              productTitle,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              preview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Row(
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
                                        const SnackBar(
                                            content: Text('已跳過下一則並重排')),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
            error: (e, _) => Center(child: Text('saved error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('products error: $e')),
      ),
    );
  }

  String _dayKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _timeOnly(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
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

  Widget _tag(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
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

class _TimelineRow {
  final bool isHeader;
  final String? dayKey;
  final PushTask? item;

  _TimelineRow._(this.isHeader, this.dayKey, this.item);

  factory _TimelineRow.header(String dayKey) => _TimelineRow._(true, dayKey, null);
  factory _TimelineRow.item(PushTask item) => _TimelineRow._(false, null, item);
}
