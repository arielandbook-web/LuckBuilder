import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../models/push_config.dart';
import '../notifications/push_orchestrator.dart';
import 'widgets/bubble_card.dart';
import '../../theme/app_tokens.dart';

class PushProductConfigPage extends ConsumerWidget {
  final String productId;
  const PushProductConfigPage({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 檢查是否登入
    String? uid;
    try {
      uid = ref.read(uidProvider);
    } catch (_) {
      return Scaffold(
        appBar: AppBar(title: const Text('商品推播設定')),
        body: const Center(child: Text('請先登入以使用此功能')),
      );
    }

    final libAsync = ref.watch(libraryProductsProvider);
    final productsAsync = ref.watch(productsMapProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('商品推播設定')),
      body: productsAsync.when(
        data: (products) => libAsync.when(
          data: (lib) {
            final lp = lib.firstWhere((e) => e.productId == productId);
            final title = products[productId]?.title ?? productId;
            final cfg = lp.pushConfig;

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                BubbleCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      
                      // 顯示完成狀態
                      if (lp.completedAt != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.tokens.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.tokens.primary),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.emoji_events, 
                                color: context.tokens.primary, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('已全部完成！',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: context.tokens.primary,
                                      ),
                                    ),
                                    Text(
                                      '完成時間：${lp.completedAt!.month}/${lp.completedAt!.day} ${lp.completedAt!.hour}:${lp.completedAt!.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.tokens.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // 重新開始按鈕
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showRestartDialog(context, ref, uid!, productId, title),
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('重新開始'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      
                      SwitchListTile.adaptive(
                        value: lp.pushEnabled,
                        onChanged: (v) async {
                          await ref
                              .read(libraryRepoProvider)
                              .setPushEnabled(uid!, productId, v);
                          ref.invalidate(libraryProductsProvider);
                          await ref.read(libraryProductsProvider.future);
                          await PushOrchestrator.rescheduleNextDays(
                              ref: ref, days: 3);
                        },
                        title: const Text('推播中'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                BubbleCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('頻率（每產品每日最多 5 次）',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      DropdownButton<int>(
                        value: cfg.freqPerDay,
                        items: const [1, 2, 3, 4, 5]
                            .map((e) => DropdownMenuItem(
                                value: e, child: Text('$e 次/天')))
                            .toList(),
                        onChanged: (v) async {
                          if (v == null) return;
                          final newCfg = cfg.copyWith(freqPerDay: v);
                          await ref
                              .read(libraryRepoProvider)
                              .setPushConfig(uid!, productId, newCfg.toMap());
                          ref.invalidate(libraryProductsProvider);
                          await ref.read(libraryProductsProvider.future);
                          await PushOrchestrator.rescheduleNextDays(
                              ref: ref, days: 3);
                        },
                      ),
                      const Divider(),
                      const Text('時間模式',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      RadioListTile<PushTimeMode>(
                        value: PushTimeMode.preset,
                        groupValue: cfg.timeMode,
                        onChanged: (v) async {
                          if (v == null) return;
                          final newCfg = cfg.copyWith(timeMode: v);
                          await ref
                              .read(libraryRepoProvider)
                              .setPushConfig(uid!, productId, newCfg.toMap());
                          ref.invalidate(libraryProductsProvider);
                          await ref.read(libraryProductsProvider.future);
                          await PushOrchestrator.rescheduleNextDays(
                              ref: ref, days: 3);
                        },
                        title: const Text('情境預設（推薦）'),
                      ),
                      if (cfg.timeMode == PushTimeMode.preset)
                        _presetSlots(ref, uid!, productId, cfg),
                      RadioListTile<PushTimeMode>(
                        value: PushTimeMode.custom,
                        groupValue: cfg.timeMode,
                        onChanged: (v) async {
                          if (v == null) return;
                          final newCfg = cfg.copyWith(timeMode: v);
                          await ref
                              .read(libraryRepoProvider)
                              .setPushConfig(uid!, productId, newCfg.toMap());
                          ref.invalidate(libraryProductsProvider);
                          await ref.read(libraryProductsProvider.future);
                          await PushOrchestrator.rescheduleNextDays(
                              ref: ref, days: 3);
                        },
                        title: const Text('自訂時間'),
                      ),
                      if (cfg.timeMode == PushTimeMode.custom)
                        _customTimes(context, ref, uid!, productId, cfg),
                      const Divider(),
                      const Text('內容策略',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      DropdownButton<PushContentMode>(
                        value: cfg.contentMode,
                        items: PushContentMode.values
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e.name)))
                            .toList(),
                        onChanged: (v) async {
                          if (v == null) return;
                          final newCfg = cfg.copyWith(contentMode: v);
                          await ref
                              .read(libraryRepoProvider)
                              .setPushConfig(uid!, productId, newCfg.toMap());
                          ref.invalidate(libraryProductsProvider);
                          await ref.read(libraryProductsProvider.future);
                          await PushOrchestrator.rescheduleNextDays(
                              ref: ref, days: 3);
                        },
                      ),
                      const SizedBox(height: 10),
                      const Text('最短間隔（分鐘）',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      DropdownButton<int>(
                        value: cfg.minIntervalMinutes,
                        items: const [60, 90, 120, 180]
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text('$e')))
                            .toList(),
                        onChanged: (v) async {
                          if (v == null) return;
                          final newCfg = cfg.copyWith(minIntervalMinutes: v);
                          await ref
                              .read(libraryRepoProvider)
                              .setPushConfig(uid!, productId, newCfg.toMap());
                          ref.invalidate(libraryProductsProvider);
                          await ref.read(libraryProductsProvider.future);
                          await PushOrchestrator.rescheduleNextDays(
                              ref: ref, days: 3);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('library error: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('products error: $e')),
      ),
    );
  }

  Widget _presetSlots(
      WidgetRef ref, String uid, String productId, PushConfig cfg) {
    const slots = ['morning', 'noon', 'evening', 'night'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((s) {
        final selected = cfg.presetSlots.contains(s);
        return FilterChip(
          selected: selected,
          label: Text(s),
          onSelected: (v) async {
            final newSlots = List<String>.from(cfg.presetSlots);
            if (v) {
              newSlots.add(s);
            } else {
              newSlots.remove(s);
            }
            final fixed = newSlots.isEmpty ? ['night'] : newSlots;
            final newCfg = cfg.copyWith(presetSlots: fixed);
            await ref
                .read(libraryRepoProvider)
                .setPushConfig(uid, productId, newCfg.toMap());
            ref.invalidate(libraryProductsProvider);
            await ref.read(libraryProductsProvider.future);
            await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
          },
        );
      }).toList(),
    );
  }

  Widget _customTimes(BuildContext context, WidgetRef ref, String uid,
      String productId, PushConfig cfg) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              if (cfg.customTimes.length >= 5) return;
              final t = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 21, minute: 40));
              if (t == null) return;

              final list = List<TimeOfDay>.from(cfg.customTimes)..add(t);
              list.sort((a, b) =>
                  (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));

              final newCfg = cfg.copyWith(customTimes: list);
              await ref
                  .read(libraryRepoProvider)
                  .setPushConfig(uid, productId, newCfg.toMap());
              ref.invalidate(libraryProductsProvider);
              await ref.read(libraryProductsProvider.future);
              await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
            },
            icon: const Icon(Icons.add),
            label: const Text('新增時間（最多 5）'),
          ),
        ),
        ...cfg.customTimes.map((t) => ListTile(
              title: Text(
                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () async {
                  final list = List<TimeOfDay>.from(cfg.customTimes)
                    ..removeWhere(
                        (x) => x.hour == t.hour && x.minute == t.minute);

                  final newCfg = cfg.copyWith(customTimes: list);
                  await ref
                      .read(libraryRepoProvider)
                      .setPushConfig(uid, productId, newCfg.toMap());
                  ref.invalidate(libraryProductsProvider);
                  await ref.read(libraryProductsProvider.future);
                  await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
                },
              ),
            )),
      ],
    );
  }

  /// 顯示重新開始確認對話框
  Future<void> _showRestartDialog(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String productId,
    String productTitle,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重新開始學習？'),
        content: Text('這將清除「$productTitle」的所有學習記錄，並重新啟用推播。\n\n確定要繼續嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('確定重新開始'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // 獲取該商品的所有內容
      final contentItems = await ref.read(contentByProductProvider(productId).future);
      final contentItemIds = contentItems.map((e) => e.id).toList();

      // 執行重置
      final repo = ref.read(libraryRepoProvider);
      await repo.resetProductProgress(
        uid: uid,
        productId: productId,
        contentItemIds: contentItemIds,
      );

      // 刷新 UI
      ref.invalidate(savedItemsProvider);
      ref.invalidate(libraryProductsProvider);
      
      // 重新排程
      await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已重新開始，推播已重新排程')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重置失敗: $e')),
        );
      }
    }
  }
}
