import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../models/global_push_settings.dart';
import '../notifications/push_orchestrator.dart';
import '../../notifications/push_skip_store.dart';
import 'push_product_config_page.dart';
import 'widgets/bubble_card.dart';
import 'widgets/push_timeline_section.dart';
import 'widgets/push_inbox_section.dart';

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
          PushTimelineSection(
            onSkip: (entry) async {
              final productId = entry.payload['productId']?.toString() ?? '';
              final contentItemId =
                  entry.payload['contentItemId']?.toString() ?? '';
              if (productId.isEmpty || contentItemId.isEmpty) return;

              final skipStore = PushSkipStore();
              await skipStore.skipOnce(
                  productId: productId, contentItemId: contentItemId);

              // 立刻重排（會自動略過該 contentItemId）
              await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已跳過下一則，並重排未來 3 天推播')),
                );
              }
            },
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 4),
          Text('更改設定後會自動重排未來 3 天推播',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
        ],
      ),
    );
  }
}
