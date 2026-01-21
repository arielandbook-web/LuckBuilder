import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/v2_providers.dart';
import '../ui/glass.dart';
import '../theme/app_tokens.dart';
import '../widgets/rich_sections/user_learning_store.dart';

class ProductPage extends ConsumerStatefulWidget {
  final String productId;
  const ProductPage({super.key, required this.productId});

  @override
  ConsumerState<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends ConsumerState<ProductPage> {
  @override
  void initState() {
    super.initState();
    // 保底記錄：進入產品頁就記一次學習
    unawaited(UserLearningStore().markGlobalLearnedToday());
  }

  @override
  Widget build(BuildContext context) {
    final prod = ref.watch(productProvider(widget.productId));
    final previews = ref.watch(previewItemsProvider(widget.productId));
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        title: const Text('產品'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: prod.when(
        data: (p) {
          if (p == null) return const Center(child: Text('商品不存在或未上架'));
          final specs = [p.spec1Label, p.spec2Label, p.spec3Label, p.spec4Label]
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassCard(
                radius: 26,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 封面圖片
                    if (p.coverImageUrl != null && p.coverImageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(26)),
                        child: Image.network(
                          p.coverImageUrl!,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            height: 200,
                            color: tokens.chipBg,
                            child: Icon(Icons.image_not_supported,
                                size: 48, color: tokens.textSecondary),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.title,
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: tokens.textPrimary)),
                          const SizedBox(height: 6),
                          Text('${p.topicId} · ${p.level}',
                              style: TextStyle(color: tokens.textSecondary)),
                          const SizedBox(height: 12),
                          if ((p.levelGoal ?? '').isNotEmpty)
                            Text(p.levelGoal!,
                                style: TextStyle(color: tokens.textPrimary)),
                          const SizedBox(height: 6),
                          if ((p.levelBenefit ?? '').isNotEmpty)
                            Text(p.levelBenefit!,
                                style: TextStyle(color: tokens.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: specs
                    .map((s) => GlassCard(
                          radius: 999,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Text(s),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              Text('│ 試讀卡片',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: tokens.textPrimary)),
              const SizedBox(height: 10),
              previews.when(
                data: (items) => SizedBox(
                  height: 160,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final it = items[i];
                      return SizedBox(
                        width: 280,
                        child: GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(it.anchor,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: tokens.textPrimary)),
                              const SizedBox(height: 6),
                              Text(it.content,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      TextStyle(color: tokens.textSecondary)),
                              const Spacer(),
                              GlassCard(
                                radius: 999,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                child: Text('${it.intent} · d${it.difficulty}'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                loading: () => const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator())),
                error: (_, __) => const SizedBox(height: 160),
              ),
              const SizedBox(height: 22),
              GlassCard(
                radius: 22,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: tokens.buttonGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: 16),
                          child: Text('訂閱解鎖全站',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text('立即訂閱'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('讀取失敗:',
                      style: TextStyle(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '$err',
                    style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
