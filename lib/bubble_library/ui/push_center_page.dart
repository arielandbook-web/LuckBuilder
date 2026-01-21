import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/global_push_settings.dart';
import '../notifications/push_orchestrator.dart';
import '../providers/providers.dart';
import '../../notifications/dnd_settings.dart';
import '../../notifications/push_skip_store.dart';
import '../../notifications/push_timeline_provider.dart';
import 'push_product_config_page.dart';
import 'widgets/bubble_card.dart';
import 'widgets/push_inbox_section.dart';

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
    final dndAsync = ref.watch(dndFuture);

    return Scaffold(
      appBar: AppBar(
        title: const Text('推播中心'),
        actions: [
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
            data: (tasks) {
              if (tasks.isEmpty) {
                return BubbleCard(
                  child: Text('目前沒有可排程的推播（可能尚未啟用推播或內容不足）',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8))),
                );
              }

              // 依日期分組
              final byDay = <String, List<dynamic>>{};
              for (final t in tasks) {
                final when = (t as dynamic).when as DateTime;
                final key =
                    '${when.year}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')}';
                byDay.putIfAbsent(key, () => []).add(t);
              }

              final dayKeys = byDay.keys.toList()..sort();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: dayKeys.map((day) {
                  final list = byDay[day]!
                    ..sort((a, b) {
                      final ta = (a as dynamic).when as DateTime;
                      final tb = (b as dynamic).when as DateTime;
                      return ta.compareTo(tb);
                    });

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: BubbleCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(builder: (_) {
                            // list 已 sort 過：第一筆=最早，最後一筆=最晚
                            final firstWhen =
                                (list.first as dynamic).when as DateTime;
                            final lastWhen =
                                (list.last as dynamic).when as DateTime;

                            String hhmm(DateTime d) =>
                                '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

                            return Row(
                              children: [
                                Text(day,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900)),
                                const Spacer(),
                                Text(
                                  '${hhmm(firstWhen)}–${hhmm(lastWhen)}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            );
                          }),
                          const SizedBox(height: 10),
                          ...list.map((t) {
                            final when = (t as dynamic).when as DateTime;
                            final productId =
                                (t as dynamic).productId.toString();
                            final item = (t as dynamic).item;
                            final cid = (item as dynamic).id.toString();

                            final title = productsAsync.maybeWhen(
                              data: (pm) => pm[productId]?.title ?? productId,
                              orElse: () => productId,
                            );

                            final hh = when.hour.toString().padLeft(2, '0');
                            final mm = when.minute.toString().padLeft(2, '0');

                            final sub =
                                '${(item as dynamic).intent}｜◆${(item as dynamic).difficulty}｜Day ${(item as dynamic).pushOrder}/365';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 54,
                                    child: Text('$hh:$mm',
                                        style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.75),
                                            fontSize: 12)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(title,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w900)),
                                        const SizedBox(height: 4),
                                        Text(sub,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.75),
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: '跳過下一則',
                                    icon: const Icon(Icons.skip_next),
                                    onPressed: () async {
                                      final uid = ref.read(uidProvider);
                                      await PushSkipStore.skip(
                                        uid: uid,
                                        productId: productId,
                                        contentItemId: cid,
                                        ttlDays: 4,
                                      );
                                      await PushOrchestrator.rescheduleNextDays(
                                          ref: ref, days: 3);
                                      ref.invalidate(upcomingTimelineProvider);

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content:
                                                  Text('已跳過下一則，並重排未來 3 天推播')),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('timeline error: $e'),
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
}
