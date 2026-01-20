import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/v2_providers.dart';
import '../ui/glass.dart';
import 'product_page.dart';

class ProductListPage extends ConsumerWidget {
  final String topicId;
  const ProductListPage({super.key, required this.topicId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsByTopicProvider(topicId));

    return Scaffold(
      appBar: AppBar(title: Text('商品 · $topicId')),
      body: products.when(
        data: (ps) => ps.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('此主題下無產品', 
                            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 12),
                          Text('Topic ID: $topicId', 
                            style: TextStyle(color: Colors.black.withValues(alpha: 0.7), fontSize: 14)),
                          const SizedBox(height: 8),
                          const Text('查詢條件:', 
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('  • published = true', 
                            style: TextStyle(color: Colors.black.withValues(alpha: 0.6), fontSize: 12)),
                          Text('  • topicId = "$topicId"', 
                            style: TextStyle(color: Colors.black.withValues(alpha: 0.6), fontSize: 12)),
                          Text('  • orderBy(order)', 
                            style: TextStyle(color: Colors.black.withValues(alpha: 0.6), fontSize: 12)),
                          const SizedBox(height: 12),
                          Text('請檢查 Firestore products 集合中的文檔是否有 topicId 欄位且值為 "$topicId"', 
                            style: TextStyle(color: Colors.orange, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78,
          ),
          itemCount: ps.length,
          itemBuilder: (_, i) {
            final p = ps[i];
            return InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProductPage(productId: p.id),
              )),
              child: GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 封面圖片
                    if (p.coverImageUrl != null && p.coverImageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: Image.network(
                          p.coverImageUrl!,
                          width: double.infinity,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 120,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text('${p.topicId} · ${p.level}'),
                            const Spacer(),
                            const Align(alignment: Alignment.bottomRight, child: Text('查看 ›')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('讀取失敗:', 
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Text('Topic ID: $topicId', 
                      style: TextStyle(color: Colors.black.withValues(alpha: 0.7), fontSize: 14)),
                    const SizedBox(height: 8),
                    const Text('錯誤訊息:', 
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('$err', 
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    const Text('查詢條件:', 
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('  • collection: products', 
                      style: TextStyle(color: Colors.black.withValues(alpha: 0.6), fontSize: 12)),
                    Text('  • published = true', 
                      style: TextStyle(color: Colors.black.withValues(alpha: 0.6), fontSize: 12)),
                    Text('  • topicId = "$topicId"', 
                      style: TextStyle(color: Colors.black.withValues(alpha: 0.6), fontSize: 12)),
                    Text('  • orderBy(order)', 
                      style: TextStyle(color: Colors.black.withValues(alpha: 0.6), fontSize: 12)),
                    const SizedBox(height: 8),
                    const Text('可能原因:', 
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('  • 缺少 Firestore 索引', 
                      style: TextStyle(color: Colors.orange, fontSize: 12)),
                    Text('  • 產品文檔缺少 topicId 欄位', 
                      style: TextStyle(color: Colors.orange, fontSize: 12)),
                    Text('  • topicId 值不匹配', 
                      style: TextStyle(color: Colors.orange, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
