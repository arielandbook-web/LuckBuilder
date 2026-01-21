import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/global_push_settings.dart';
import '../models/user_library.dart';
import '../notifications/push_orchestrator.dart';
import '../providers/providers.dart';
import '../../notifications/dnd_settings.dart';
import '../../notifications/push_timeline_provider.dart';
import '../../notifications/skip_next_store.dart';
import 'push_product_config_page.dart';
import 'widgets/bubble_card.dart';
import 'widgets/push_inbox_section.dart';
import '../../../pages/push_inbox_page.dart';
import '../../../pages/push_timeline_page.dart';
import 'product_library_page.dart';
import '../../notifications/widgets/timeline_widgets.dart';
import '../../notifications/timeline_meta_mode.dart';
import '../../notifications/widgets/push_hint.dart';
import '../../notifications/push_timeline_list.dart';

final dndFuture = FutureProvider.autoDispose<DndSettings>((ref) async {
  final uid = ref.read(uidProvider);
  return DndSettingsStore.load(uid);
});

class PushCenterPage extends ConsumerWidget {
  const PushCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalAsync = ref.watch(globalPushSettingsProvider);
    final libAsync = ref.watch(libraryProductsProvider);
    final productsAsync = ref.watch(productsMapProvider);
    final timelineAsync = ref.watch(upcomingTimelineProvider);
    final savedAsync = ref.watch(savedItemsProvider);
    final dndAsync = ref.watch(dndFuture);

    return Scaffold(
      appBar: AppBar(
        title: const Text('推播中心'),
        actions: [
          IconButton(
            icon: const Icon(Icons.inbox_outlined),
            tooltip: '推播收件匣',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PushInboxPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.timeline),
            tooltip: '未來 3 天時間表',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PushTimelinePage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
              // ignore: use_build_context_synchronously
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('已重排未來 3 天推播')));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          globalAsync.when(
            data: (g) => _globalCard(context, ref, g),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('global error: $e'),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('未來 3 天時間表',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(width: 10),
              Expanded(
                child: dndAsync.when(
                  data: (s) {
                    if (!s.enabled) return const SizedBox.shrink();
                    return Text(
                      '已套用勿擾 ${fmtTimeMin(s.startMin)}–${fmtTimeMin(s.endMin)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          timelineAsync.when(
            data: (list) {
              if (list.isEmpty) {
                return BubbleCard(
                  child: Text('尚未產生 timeline（可按右上角刷新重排 3 天）',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8))),
                );
              }

              // 排序（以 when）
              final items = List.of(list);
              items.sort((a, b) {
                try {
                  final wa = (a as dynamic).when as DateTime;
                  final wb = (b as dynamic).when as DateTime;
                  return wa.compareTo(wb);
                } catch (_) {
                  return 0;
                }
              });

              // 找每個 product 的第一則（才顯示「跳過下一則」）
              final firstIdxByProduct = <String, int>{};
              for (int i = 0; i < items.length; i++) {
                final t = items[i];
                final pid = (t as dynamic).productId?.toString() ?? '';
                if (pid.isEmpty) continue;
                firstIdxByProduct.putIfAbsent(pid, () => i);
              }

              return productsAsync.when(
                data: (productsMap) {
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length.clamp(0, 40),
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final t = items[i];
                      final pid = (t as dynamic).productId?.toString() ?? '';
                      final when = (t as dynamic).when as DateTime?;
                      final cid = (t as dynamic).contentItemId?.toString() ??
                          (t as dynamic).itemId?.toString() ??
                          (t as dynamic).contentId?.toString() ??
                          ((t as dynamic).item != null
                              ? ((t as dynamic).item as dynamic).id?.toString()
                              : '') ??
                          '';

                      final title = productsMap[pid]?.title ?? pid;
                      final isFirst = firstIdxByProduct[pid] == i;

                      return BubbleCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.schedule, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 6),
                                  Text(
                                    when == null
                                        ? '時間未知'
                                        : '${when.year}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')} '
                                          '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.75),
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            if (isFirst)
                              TextButton(
                                onPressed: (pid.isEmpty || cid.isEmpty)
                                    ? null
                                    : () async {
                                        final uid = ref.read(uidProvider);
                                        await SkipNextStore.add(uid, cid);

                                        await PushOrchestrator.rescheduleNextDays(
                                            ref: ref, days: 3);

                                        ref.invalidate(upcomingTimelineProvider);

                                        // ignore: use_build_context_synchronously
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content:
                                                  Text('已跳過下一則，並重排未來 3 天')),
                                        );
                                      },
                                child: const Text('跳過下一則'),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('products error: $e'),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('timeline error: $e'),
          ),
          const SizedBox(height: 12),

          // ✅ 未來 3 天時間表（嵌入式預覽）
          _timelinePreview(
            context: context,
            ref: ref,
            timelineAsync: timelineAsync,
            productsAsync: productsAsync,
            savedAsync: savedAsync,
            libAsync: libAsync,
          ),

          const SizedBox(height: 12),
          const Text('推播中',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          productsAsync.when(
            data: (products) {
              return libAsync.when(
                data: (lib) {
                  final pushing =
                      lib.where((e) => !e.isHidden && e.pushEnabled).toList();
                  if (pushing.isEmpty) {
                    return BubbleCard(
                        child: Text('目前沒有推播中的商品',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8))));
                  }
                  return Column(
                    children: pushing.map((lp) {
                      final title =
                          products[lp.productId]?.title ?? lp.productId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: BubbleCard(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => PushProductConfigPage(
                                    productId: lp.productId)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.notifications_active, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 6),
                                    Text(
                                        '頻率：${lp.pushConfig.freqPerDay}/天｜模式：${lp.pushConfig.timeMode.name}',
                                        style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.75),
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('library error: $e'),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('products error: $e'),
          ),
          const SizedBox(height: 16),
          const PushInboxSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _globalCard(
      BuildContext context, WidgetRef ref, GlobalPushSettings g) {
    final uid = ref.read(uidProvider);
    final repo = ref.read(pushSettingsRepoProvider);

    return BubbleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('全域設定',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            value: g.enabled,
            onChanged: (v) async {
              await repo.setGlobal(uid, g.copyWith(enabled: v));
              await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
            },
            title: const Text('啟用推播'),
          ),
          ListTile(
            title: const Text('每日總上限（跨商品）'),
            subtitle: Text('${g.dailyTotalCap} 則/天'),
            trailing: DropdownButton<int>(
              value: g.dailyTotalCap,
              items: const [6, 8, 12, 20]
                  .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                  .toList(),
              onChanged: (v) async {
                if (v == null) return;
                await repo.setGlobal(uid, g.copyWith(dailyTotalCap: v));
                await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
              },
            ),
          ),
          ListTile(
            title: const Text('推播樣式'),
            subtitle: Text(g.styleMode),
            trailing: DropdownButton<String>(
              value: g.styleMode,
              items: const ['compact', 'standard', 'interactive']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) async {
                if (v == null) return;
                await repo.setGlobal(uid, g.copyWith(styleMode: v));
                await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
              },
            ),
          ),
          const Divider(height: 24),
          FutureBuilder<DndSettings>(
            future: DndSettingsStore.load(uid),
            builder: (context, snap) {
              final s0 = snap.data ?? DndSettings.defaults;

              return StatefulBuilder(
                builder: (context, setLocal) {
                  Future<void> saveAndReschedule(DndSettings next) async {
                    await DndSettingsStore.save(uid, next);
                    await PushOrchestrator.rescheduleNextDays(
                        ref: ref, days: 3);
                    ref.invalidate(upcomingTimelineProvider);
                    ref.invalidate(dndFuture);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                '已更新勿擾：${next.enabled ? "${fmtTimeMin(next.startMin)}–${fmtTimeMin(next.endMin)}" : "關閉"}')),
                      );
                    }
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('勿擾時段',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        value: s0.enabled,
                        onChanged: (v) async {
                          final next = s0.copyWith(enabled: v);
                          setLocal(() {});
                          await saveAndReschedule(next);
                        },
                        title: const Text('啟用勿擾（排程自動避開）'),
                        subtitle: Text(
                            '${fmtTimeMin(s0.startMin)}–${fmtTimeMin(s0.endMin)}'),
                      ),
                      if (s0.enabled) ...[
                        ListTile(
                          title: const Text('開始時間'),
                          subtitle: Text(fmtTimeMin(s0.startMin)),
                          trailing: const Icon(Icons.access_time),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: minToTimeOfDay(s0.startMin),
                            );
                            if (picked == null) return;
                            final next =
                                s0.copyWith(startMin: timeOfDayToMin(picked));
                            setLocal(() {});
                            await saveAndReschedule(next);
                          },
                        ),
                        ListTile(
                          title: const Text('結束時間'),
                          subtitle: Text(fmtTimeMin(s0.endMin)),
                          trailing: const Icon(Icons.access_time),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: minToTimeOfDay(s0.endMin),
                            );
                            if (picked == null) return;
                            final next =
                                s0.copyWith(endMin: timeOfDayToMin(picked));
                            setLocal(() {});
                            await saveAndReschedule(next);
                          },
                        ),
                        Text(
                          '提示：支援跨午夜（例如 22:00–07:00）',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12),
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 4),
          Text('更改設定後會自動重排未來 3 天推播',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _timelinePreview({
    required BuildContext context,
    required WidgetRef ref,
    required AsyncValue timelineAsync,
    required AsyncValue productsAsync,
    required AsyncValue savedAsync,
    required AsyncValue libAsync,
  }) {
    final metaMode = ref.watch(timelineMetaModeProvider);

    return BubbleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              TextButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) {
                      return DraggableScrollableSheet(
                        initialChildSize: 0.92,
                        minChildSize: 0.6,
                        maxChildSize: 0.98,
                        expand: false,
                        builder: (_, controller) {
                          return ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                            child: Material(
                              color: Colors.black.withValues(alpha: 0.25),
                              child: PushTimelineList(
                                showTopBar: false,
                                onClose: () => Navigator.of(ctx).pop(),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
                child: const Text('查看全部'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          productsAsync.when(
            data: (productsMap) {
              return libAsync.when(
                data: (lib) {
                  final libMap = <String, UserLibraryProduct>{};
                  for (final lp in lib) {
                    libMap[lp.productId] = lp;
                  }

                  return savedAsync.when(
                    data: (savedMap) {
                      return timelineAsync.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return Text('目前沒有已排程的推播',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75)));
                      }

                      // ✅ 預覽前 6 筆
                      final preview = items.take(6).toList();

                      // ✅ 分日 + 同日同商品第 N 則
                      final groups = <String, List<dynamic>>{};
                      for (final it in preview) {
                        final when = (it as dynamic).when as DateTime;
                        final dk = tlDayKey(when);
                        (groups[dk] ??= []).add(it);
                      }

                      final dayKeys = groups.keys.toList()..sort();

                      final rows = <TLRow>[];
                      for (final dk in dayKeys) {
                        rows.add(TLRow.header(dk));

                        final list = groups[dk]!
                          ..sort((a, b) {
                            final wa = (a as dynamic).when as DateTime;
                            final wb = (b as dynamic).when as DateTime;
                            return wa.compareTo(wb);
                          });

                        final cntByProduct = <String, int>{};
                        for (final t in list) {
                          final pid = (t as dynamic).productId as String;
                          final n = (cntByProduct[pid] ?? 0) + 1;
                          cntByProduct[pid] = n;
                          rows.add(TLRow.item(t, seqInDayForProduct: n));
                        }
                      }

                      return Column(
                        children: [
                          ...List.generate(rows.length, (index) {
                            final r = rows[index];

                            if (r.isHeader) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6, bottom: 8),
                                child: Text(
                                  r.dayKey!,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              );
                            }

                            final it = r.item!;
                            final when = (it as dynamic).when as DateTime;
                            final productId = (it as dynamic).productId as String;
                            final item = (it as dynamic).item;
                            final contentItemId = (item as dynamic).id as String;
                            final previewText = (item as dynamic).content as String?;

                            final productTitle =
                                productsMap[productId]?.title ?? productId;

                            final day = (item as dynamic).pushOrder as int?;
                            final saved = savedMap[contentItemId];

                            // ✅ 當日第一/最後：用 rows 判斷（header 分隔）
                            final isFirstItemOfDay =
                                index > 0 && rows[index - 1].isHeader;
                            final isLastItemOfDay =
                                (index + 1 >= rows.length) || rows[index + 1].isHeader;

                            final metaMode = ref.watch(timelineMetaModeProvider);
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

                            return tlTimelineRow(
                              context: context,
                              when: when,
                              title: productTitle,
                              preview: previewText ?? '',
                              metaText: metaText(),
                              saved: saved,
                              seqInDay: r.seqInDayForProduct,
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
                            );
                          }),
                        ],
                      );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('timeline error: $e'),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('saved error: $e'),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('library error: $e'),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('products error: $e'),
        ),
        ],
      ),
    );
  }
}
