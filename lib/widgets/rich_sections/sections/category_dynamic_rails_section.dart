import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/v2_providers.dart';
import '../../../theme/app_tokens.dart';
import '../../app_card.dart';
import '../../../data/models.dart';
import '../../../pages/product_page.dart';

class CategoryDynamicRailsSection extends ConsumerWidget {
  const CategoryDynamicRailsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;

    final segsAsync = ref.watch(segmentsProvider);
    final selected = ref.watch(selectedSegmentProvider);

    return segsAsync.when(
      data: (segs) {
        // 取目前 segment（若尚未選，fallback 第一個）
        final seg = selected ?? (segs.isNotEmpty ? segs.first : null);

        // 依 segment 做 listId（你之後 Firestore 用這些 id 建 featured_lists 文件）
        final segId = seg?.id ?? 'all';
        final newId = 'cat_new_$segId';
        final hotId = 'cat_hot_$segId';
        final forYouId = 'cat_for_you_$segId';

        final newAsync = ref.watch(featuredProductsProvider(newId));
        final hotAsync = ref.watch(featuredProductsProvider(hotId));
        final forYouAsync = ref.watch(featuredProductsProvider(forYouId));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '為你推薦',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _RailBlock(
              title: '適合你',
              async: forYouAsync,
              emptyHint: '無資料（請檢查 Firestore featured_lists/$forYouId）',
            ),
            const SizedBox(height: 14),
            _RailBlock(
              title: '新上架',
              async: newAsync,
              emptyHint: '無資料（請檢查 Firestore featured_lists/$newId）',
            ),
            const SizedBox(height: 14),
            _RailBlock(
              title: '最多人解鎖',
              async: hotAsync,
              emptyHint: '無資料（請檢查 Firestore featured_lists/$hotId）',
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('CategoryDynamicRailsSection error: $e',
              style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}

class _RailBlock extends StatelessWidget {
  final String title;
  final AsyncValue<List<Product>> async;
  final String emptyHint;

  const _RailBlock({
    required this.title,
    required this.async,
    required this.emptyHint,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return async.when(
      data: (ps) {
        if (ps.isEmpty) {
          return AppCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(emptyHint,
                  style: TextStyle(color: tokens.textSecondary)),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('│ $title',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: tokens.textPrimary,
                )),
            const SizedBox(height: 10),
            SizedBox(
              height: 170,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ps.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final p = ps[i];
                  return _MiniProductCard(product: p);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 170,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text('$title error: $e',
              style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}

class _MiniProductCard extends StatelessWidget {
  final Product product;
  const _MiniProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SizedBox(
      width: 240,
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProductPage(productId: product.id)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // cover
            if (product.coverImageUrl != null &&
                product.coverImageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.network(
                  product.coverImageUrl!,
                  width: double.infinity,
                  height: 92,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 92,
                    color: tokens.chipBg,
                    child: Icon(Icons.image_not_supported,
                        color: tokens.textSecondary),
                  ),
                ),
              )
            else
              Container(
                height: 92,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: tokens.chipBg,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Icon(Icons.auto_awesome, color: tokens.textSecondary),
              ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${product.topicId} · ${product.level}',
                    style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                  ),
                  if (product.levelGoal != null &&
                      product.levelGoal!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      product.levelGoal!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: tokens.textSecondary, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
