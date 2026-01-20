import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/v2_providers.dart';
import '../widgets/app_card.dart';
import '../theme/app_tokens.dart';
import 'product_page.dart';

class SearchPage extends ConsumerWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    final tokens = context.tokens;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                autofocus: true,
                style: TextStyle(color: tokens.textPrimary),
                decoration: InputDecoration(
                  hintText: '搜尋產品 / 主題…',
                  hintStyle: TextStyle(color: tokens.textSecondary),
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: tokens.textSecondary),
                ),
                onChanged: (value) {
                  ref.read(searchQueryProvider.notifier).state = value;
                },
              ),
            ),
          ),
          Expanded(
            child: results.when(
              data: (products) {
                if (query.isEmpty) {
                  return Center(
                    child: Text('輸入關鍵字開始搜尋', style: TextStyle(fontSize: 16, color: tokens.textSecondary)),
                  );
                }
                if (products.isEmpty) {
                  return Center(
                    child: Text('找不到「$query」的結果', style: TextStyle(fontSize: 16, color: tokens.textSecondary)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final product = products[index];
                    return AppCard(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProductPage(productId: product.id),
                      )),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.title,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tokens.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${product.topicId} · ${product.level}',
                            style: TextStyle(color: tokens.textSecondary),
                          ),
                          if (product.levelGoal != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              product.levelGoal!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: tokens.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('搜尋錯誤:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('$error', 
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
