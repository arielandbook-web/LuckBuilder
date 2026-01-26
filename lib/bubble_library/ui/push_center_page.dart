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
import '../../../pages/push_timeline_page.dart';
import '../../../notifications/push_timeline_provider.dart';
import '../../theme/app_tokens.dart';

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
            icon: const Icon(Icons.timeline),
            tooltip: '未來 3 天時間表',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PushTimelinePage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              try {
                final result = await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
                // ignore: use_build_context_synchronously
                if (result.overCap) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '總推播數超過每日上限（${result.totalEffectiveFreq} > ${result.dailyCap}），部分排程可能被裁切',
                      ),
                    ),
                  );
                  return;
                }
                final global = await ref.read(globalPushSettingsProvider.future);
                final scheduled = await ref.read(scheduledCacheProvider.future);
                // ignore: use_build_context_synchronously
                final message = !global.enabled
                    ? '推播已關閉，無法排程'
                    : scheduled.isEmpty
                        ? '重排完成，但沒有產生排程（請檢查產品設定）'
                        : '已重排未來 3 天推播（${scheduled.length} 則）';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              } catch (e) {
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('重排失敗: $e')),
                );
              }
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
          const Text('推播中',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          productsAsync.when(
            data: (products) {
              return libAsync.when(
                data: (lib) {
                  final pushing =
                      lib.where((e) => !e.isHidden && e.pushEnabled).toList();
                  final completed =
                      lib.where((e) => !e.isHidden && !e.pushEnabled && e.completedAt != null).toList();
                  
                  if (pushing.isEmpty && completed.isEmpty) {
                    final tokens = context.tokens;
                    return BubbleCard(
                        child: Text('目前沒有推播中的商品',
                            style: TextStyle(
                                color: tokens.textSecondary)));
                  }
                  
                  return Column(
                    children: [
                      // 推播中的商品
                      ...pushing.map((lp) {
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
                      
                      // 已完成的商品
                      if (completed.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        BubbleCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.emoji_events, 
                                    size: 20, 
                                    color: context.tokens.primary),
                                  const SizedBox(width: 8),
                                  Text('已全部完成',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: context.tokens.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...completed.map((lp) {
                                final title = products[lp.productId]?.title ?? lp.productId;
                                final completedDate = lp.completedAt != null
                                    ? '${lp.completedAt!.month}/${lp.completedAt!.day}'
                                    : '';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => PushProductConfigPage(
                                          productId: lp.productId,
                                        ),
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          Icon(Icons.check_circle, 
                                            size: 20, 
                                            color: context.tokens.primary),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(title,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          if (completedDate.isNotEmpty)
                                            Text(completedDate,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: context.tokens.textSecondary,
                                              ),
                                            ),
                                          const SizedBox(width: 8),
                                          Icon(Icons.chevron_right,
                                            size: 18,
                                            color: context.tokens.textSecondary),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ],
                    ],
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
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '若產品推播加總數量超過每日總上限，部分橫幅通知會被延後推播',
                    style: TextStyle(
                      color: context.tokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
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
                  color: context.tokens.textSecondary, fontSize: 12)),
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
