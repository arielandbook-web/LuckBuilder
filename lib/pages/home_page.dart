import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/v2_providers.dart';
import '../ui/glass.dart';
import '../data/models.dart';
import 'product_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(bannerProductsProvider);
    final weekly = ref.watch(featuredProductsProvider('weekly_pick'));
    final hot = ref.watch(featuredProductsProvider('hot_all'));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 小搜尋列（點了跳到搜尋tab：你之後可改成 ref.read(bottomTabIndexProvider)=2）
          const GlassCard(
            child: Row(
              children: [
                Icon(Icons.search),
                SizedBox(width: 8),
                Text('搜尋產品 / 主題…'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Banner 1~3
          banners.when(
            data: (ps) => ps.isEmpty
                ? const GlassCard(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Banner: 無資料（請檢查 Firestore featured_lists/home_banners）', 
                        style: TextStyle(color: Colors.red)),
                    ),
                  )
                : SizedBox(
                    height: 160,
                    child: PageView.builder(
                      itemCount: ps.length,
                      itemBuilder: (_, i) => _BannerCard(
                        product: ps[i],
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ProductPage(productId: ps[i].id),
                        )),
                      ),
                    ),
                  ),
            loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
            error: (err, stack) => GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Banner 錯誤:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('$err', 
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          const _Section(title: '本週精選'),
          weekly.when(
            data: (ps) => ps.isEmpty
                ? const GlassCard(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('本週精選: 無資料', style: TextStyle(color: Colors.orange)),
                    ),
                  )
                : _Rail(products: ps),
            loading: () => const SizedBox(height: 210, child: Center(child: CircularProgressIndicator())),
            error: (err, stack) => GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('本週精選錯誤:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('$err', 
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          const _Section(title: '熱門爆款'),
          hot.when(
            data: (ps) => ps.isEmpty
                ? const GlassCard(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('熱門爆款: 無資料', style: TextStyle(color: Colors.orange)),
                    ),
                  )
                : _Rail(products: ps),
            loading: () => const SizedBox(height: 210, child: Center(child: CircularProgressIndicator())),
            error: (err, stack) => GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('熱門爆款錯誤:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('$err', 
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text('│ $title', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const _BannerCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        child: GlassCard(
          radius: 26,
          child: Stack(
            children: [
              // 背景圖片
              if (product.coverImageUrl != null && product.coverImageUrl!.isNotEmpty)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Image.network(
                      product.coverImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(),
                    ),
                  ),
                ),
              // 內容層
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(product.levelGoal ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    const Align(alignment: Alignment.bottomRight, child: Text('立即查看 ›')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  final List<Product> products;
  const _Rail({required this.products});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final p = products[i];
          return InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ProductPage(productId: p.id),
            )),
            child: SizedBox(
              width: 280,
              height: 210,
              child: GlassCard(
                padding: EdgeInsets.zero,
                child: SizedBox(
                  height: 210,
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
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              Text('${p.topicId} · ${p.level}', style: TextStyle(color: Colors.black.withValues(alpha: 0.55))),
                              const Spacer(),
                              const Align(alignment: Alignment.bottomRight, child: Text('訂閱解鎖')),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
