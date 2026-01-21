import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/v2_providers.dart';
import '../providers/nav_providers.dart';
import '../widgets/app_card.dart';
import '../theme/app_tokens.dart';
import '../data/models.dart';
import '../ui/rich_sections/home_today_task_section.dart';
import '../ui/rich_sections/home_continue_section.dart';
import '../ui/rich_sections/home_status_section.dart';
import '../widgets/rich_sections/sections/home_for_you_section.dart';
import '../widgets/rich_sections/user_learning_store.dart';
import '../bubble_library/ui/product_library_page.dart';
import 'product_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(bannerProductsProvider);
    final weekly = ref.watch(featuredProductsProvider('weekly_pick'));
    final hot = ref.watch(featuredProductsProvider('hot_all'));
    final newArrivals = ref.watch(newArrivalsProvider);
    final tokens = context.tokens;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 小搜尋列（點了跳到搜尋tab）
          AppCard(
            padding: const EdgeInsets.all(14),
            onTap: () {
              ref.read(bottomTabIndexProvider.notifier).state = 3; // 跳到搜尋 tab
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: tokens.searchBarGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: tokens.textSecondary),
                  const SizedBox(width: 8),
                  Text('搜尋產品 / 主題…',
                      style: TextStyle(color: tokens.textSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 今日任務區塊
          const HomeTodayTaskSection(dailyLimit: 20),
          const SizedBox(height: 12),

          // 繼續學習區塊
          HomeContinueSection(
            onContinue: (productId, day) {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProductLibraryPage(
                  productId: productId,
                  isWishlistPreview: false,
                ),
              ));
            },
          ),
          const SizedBox(height: 12),

          // 學習狀態區塊
          const HomeStatusSection(),
          const SizedBox(height: 12),

          // 為你推薦
          const HomeForYouSection(),
          const SizedBox(height: 18),

          // 本週新泡泡
          const _Section(title: '本週新泡泡'),
          newArrivals.when(
            data: (ps) => ps.isEmpty
                ? AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('本週新泡泡: 無資料',
                          style: TextStyle(color: tokens.textSecondary)),
                    ),
                  )
                : _Rail(products: ps),
            loading: () => const SizedBox(
                height: 210, child: Center(child: CircularProgressIndicator())),
            error: (err, stack) => AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('本週新泡泡錯誤:',
                        style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '$err',
                      style:
                          TextStyle(color: tokens.textSecondary, fontSize: 12),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Banner 1~3
          banners.when(
            data: (ps) => ps.isEmpty
                ? AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                          'Banner: 無資料（請檢查 Firestore featured_lists/home_banners）',
                          style: TextStyle(color: tokens.textSecondary)),
                    ),
                  )
                : SizedBox(
                    height: 160,
                    child: PageView.builder(
                      itemCount: ps.length,
                      itemBuilder: (_, i) => _BannerCard(
                        product: ps[i],
                        onTap: () {
                          unawaited(
                              UserLearningStore().markGlobalLearnedToday());
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ProductPage(productId: ps[i].id),
                          ));
                        },
                      ),
                    ),
                  ),
            loading: () => const SizedBox(
                height: 160, child: Center(child: CircularProgressIndicator())),
            error: (err, stack) => AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Banner 錯誤:',
                        style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '$err',
                      style:
                          TextStyle(color: tokens.textSecondary, fontSize: 12),
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
                ? AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('本週精選: 無資料',
                          style: TextStyle(color: tokens.textSecondary)),
                    ),
                  )
                : _Rail(products: ps),
            loading: () => const SizedBox(
                height: 210, child: Center(child: CircularProgressIndicator())),
            error: (err, stack) => AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('本週精選錯誤:',
                        style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '$err',
                      style:
                          TextStyle(color: tokens.textSecondary, fontSize: 12),
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
                ? AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('熱門爆款: 無資料',
                          style: TextStyle(color: tokens.textSecondary)),
                    ),
                  )
                : _Rail(products: ps),
            loading: () => const SizedBox(
                height: 210, child: Center(child: CircularProgressIndicator())),
            error: (err, stack) => AppCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('熱門爆款錯誤:',
                        style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '$err',
                      style:
                          TextStyle(color: tokens.textSecondary, fontSize: 12),
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
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text('│ $title',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary)),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const _BannerCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
          ),
          child: Stack(
            children: [
              // 背景圖片
              if (product.coverImageUrl != null &&
                  product.coverImageUrl!.isNotEmpty)
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
              // 漸變遮罩
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),
              // 內容層
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.levelGoal ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: tokens.buttonGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: tokens.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          '立即查看 ›',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
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
          return AppCard(
            padding: EdgeInsets.zero,
            onTap: () {
              unawaited(UserLearningStore().markGlobalLearnedToday());
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProductPage(productId: p.id),
              ));
            },
            child: SizedBox(
              width: 280,
              height: 210,
              child: Builder(
                builder: (context) {
                  final tokens = context.tokens;
                  return SizedBox(
                    height: 210,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 封面圖片
                        if (p.coverImageUrl != null &&
                            p.coverImageUrl!.isNotEmpty)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20)),
                            child: Image.network(
                              p.coverImageUrl!,
                              width: double.infinity,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                height: 120,
                                color: tokens.chipBg,
                                child: Icon(Icons.image_not_supported,
                                    color: tokens.textSecondary),
                              ),
                            ),
                          ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(p.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: tokens.textPrimary)),
                                ),
                                const SizedBox(height: 4),
                                Text('${p.topicId} · ${p.level}',
                                    style:
                                        TextStyle(color: tokens.textSecondary)),
                                const SizedBox(height: 4),
                                Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text('訂閱解鎖',
                                        style: TextStyle(
                                            color: tokens.primary,
                                            fontWeight: FontWeight.w600))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
