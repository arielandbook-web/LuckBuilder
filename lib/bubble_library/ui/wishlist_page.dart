import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../collections/wishlist_provider.dart';
import '../providers/providers.dart';
import '../models/product.dart';
import '../models/user_library.dart';
import 'product_library_page.dart';
import '../../pages/product_page.dart';

class WishlistPage extends ConsumerWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsMapProvider);
    final wishlistAsync = ref.watch(localWishlistProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('未購買收藏'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(localWishlistNotifierProvider).refresh(),
          ),
        ],
      ),
      body: productsAsync.when(
        data: (productsMap) {
          return wishlistAsync.when(
            data: (wishItems) {
                  final list = wishItems
                  .where((w) => productsMap.containsKey(w.productId))
                  .map((w) => {
                    'item': w,
                    'product': productsMap[w.productId]!,
                  })
                  .toList()
                ..sort((a, b) => (b['item'] as WishlistItem).addedAt
                    .compareTo((a['item'] as WishlistItem).addedAt));

              if (list.isEmpty) {
                return const Center(child: Text('目前沒有收藏的未購買商品'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final w = list[i]['item'] as WishlistItem;
                  final p = list[i]['product'] as Product;
                  final pid = p.id;
                  final title = p.title;
                  final subtitle = p.levelGoal ?? '';

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(title,
                                    style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.w900)),
                              ),
                              IconButton(
                                tooltip: '最愛',
                                icon: Icon(w.isFavorite
                                    ? Icons.star
                                    : Icons.star_border),
                                onPressed: () => ref
                                    .read(localWishlistNotifierProvider)
                                    .toggleFavorite(pid),
                              ),
                            ],
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.visibility),
                                label: const Text('試讀'),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ProductLibraryPage(
                                        productId: pid,
                                        isWishlistPreview: true,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.shopping_bag_outlined),
                                label: const Text('去購買'),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ProductPage(productId: pid),
                                    ),
                                  );
                                },
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: '移除收藏',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => ref
                                    .read(localWishlistNotifierProvider)
                                    .remove(pid),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('wishlist error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('products error: $e')),
      ),
    );
  }
}
