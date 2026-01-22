import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/global_push_settings.dart';
import '../models/push_config.dart';
import '../notifications/push_orchestrator.dart';
import '../notifications/notification_service.dart';
import '../providers/providers.dart';
import 'push_product_config_page.dart';
import 'widgets/bubble_card.dart';
import 'widgets/push_inbox_section.dart';
import '../../notifications/notification_inbox_page.dart';
import '../../../pages/push_timeline_page.dart';
import '../../notifications/timeline_meta_mode.dart';
import '../../notifications/push_timeline_list.dart';

class PushCenterPage extends ConsumerWidget {
  const PushCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalAsync = ref.watch(globalPushSettingsProvider);
    final libAsync = ref.watch(libraryProductsProvider);
    final productsAsync = ref.watch(productsMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('推播中心'),
        actions: [
          IconButton(
            icon: const Icon(Icons.inbox_outlined),
            tooltip: '推播收件匣',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationInboxPage(showMissedOnly: true)),
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
          IconButton(
            icon: const Icon(Icons.campaign),
            tooltip: '試播一則',
            onPressed: () async {
              await NotificationService().showTestBubbleNotification();
              // ignore: use_build_context_synchronously
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已發送測試通知')),
              );
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
          // ✅ 推播收件匣入口
          ListTile(
            leading: const Icon(Icons.inbox_outlined),
            title: const Text('推播收件匣（錯過推播）'),
            subtitle: const Text('把你沒點到的推播集中起來補看'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const NotificationInboxPage(showMissedOnly: true)),
            ),
          ),

          // ✅ 未來 3 天時間表入口
          ListTile(
            leading: const Icon(Icons.timeline),
            title: const Text('未來 3 天時間表'),
            subtitle: const Text('查看將收到哪些 Topic，可跳過下一則'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PushTimelinePage()),
            ),
          ),

          const SizedBox(height: 12),

          // ✅ 未來 3 天時間表（嵌入式預覽）
          _timelinePreview(
            context: context,
            ref: ref,
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
          SwitchTheme(
            data: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Theme.of(context).colorScheme.primary;
                }
                return null;
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Theme.of(context).colorScheme.primary.withOpacity(0.5);
                }
                return null;
              }),
            ),
            child: SwitchListTile.adaptive(
              value: g.enabled,
              onChanged: (v) async {
                final newSettings = g.copyWith(enabled: v);
                // ✅ 並行執行：寫入 Firestore 和重排同時進行
                final writeFuture = repo.setGlobal(uid, newSettings);
                final rescheduleFuture = PushOrchestrator.rescheduleNextDays(
                  ref: ref,
                  days: 3,
                  overrideGlobal: newSettings,
                );
                await Future.wait([writeFuture, rescheduleFuture]);
              },
              title: const Text('啟用推播'),
            ),
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
                final newSettings = g.copyWith(dailyTotalCap: v);
                // ✅ 並行執行：寫入 Firestore 和重排同時進行
                final writeFuture = repo.setGlobal(uid, newSettings);
                final rescheduleFuture = PushOrchestrator.rescheduleNextDays(
                  ref: ref,
                  days: 3,
                  overrideGlobal: newSettings,
                );
                await Future.wait([writeFuture, rescheduleFuture]);
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
                final newSettings = g.copyWith(styleMode: v);
                // ✅ 並行執行：寫入 Firestore 和重排同時進行
                final writeFuture = repo.setGlobal(uid, newSettings);
                final rescheduleFuture = PushOrchestrator.rescheduleNextDays(
                  ref: ref,
                  days: 3,
                  overrideGlobal: newSettings,
                );
                await Future.wait([writeFuture, rescheduleFuture]);
              },
            ),
          ),
          // ✅ 勿擾 / 靜音時段（全域）
          ListTile(
            title: const Text('勿擾時段（全域）'),
            subtitle: Text(
                '${_fmtTod(g.quietHours.start)} – ${_fmtTod(g.quietHours.end)}'),
            trailing: const Icon(Icons.bedtime_outlined),
            onTap: () async {
              final start = await _pickTime(context, g.quietHours.start);
              if (start == null) return;
              final end = await _pickTime(context, g.quietHours.end);
              if (end == null) return;

              final next = g.copyWith(
                quietHours: TimeRange(start, end),
              );

              // ✅ 並行執行：寫入 Firestore 和重排同時進行
              final writeFuture = repo.setGlobal(uid, next);
              final rescheduleFuture = PushOrchestrator.rescheduleNextDays(
                ref: ref,
                days: 3,
                overrideGlobal: next,
              );
              await Future.wait([writeFuture, rescheduleFuture]);

              // ignore: use_build_context_synchronously
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        '已設定勿擾：${_fmtTod(start)} – ${_fmtTod(end)}')),
              );
            },
          ),
          // （可選）快速關閉勿擾
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.restore),
              label: const Text('關閉勿擾'),
              onPressed: () async {
                final next = g.copyWith(
                  quietHours: TimeRange(
                    const TimeOfDay(hour: 0, minute: 0),
                    const TimeOfDay(hour: 0, minute: 0),
                  ),
                );
                // ✅ 並行執行：寫入 Firestore 和重排同時進行
                final writeFuture = repo.setGlobal(uid, next);
                final rescheduleFuture = PushOrchestrator.rescheduleNextDays(
                  ref: ref,
                  days: 3,
                  overrideGlobal: next,
                );
                await Future.wait([writeFuture, rescheduleFuture]);

                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已關閉勿擾（00:00 – 00:00）')),
                );
              },
            ),
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
  }) {
    final metaMode = ref.watch(timelineMetaModeProvider);

    return BubbleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    onSelectionChanged: (s) =>
                        ref.read(timelineMetaModeProvider.notifier).state = s.first,
                    showSelectedIcon: false,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
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
                child: const Text('查看全部', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 400, // 限制預覽高度
            child: PushTimelineList(
              showTopBar: false,
              limit: 6,
              dense: true,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtTod(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<TimeOfDay?> _pickTime(BuildContext context, TimeOfDay initial) {
    return showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        // 讓顏色不要太突兀（可留可不留）
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: Theme.of(context).colorScheme.surface,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
