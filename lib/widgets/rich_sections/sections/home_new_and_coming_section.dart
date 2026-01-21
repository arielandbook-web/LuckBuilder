import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_tokens.dart';
import '../../app_card.dart';

import '../../../providers/v2_providers.dart';
import '../../../data/models.dart';
import '../../../pages/product_page.dart';

class HomeNewAndComingSection extends ConsumerWidget {
  const HomeNewAndComingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsMapAsync = ref.watch(allProductsMapProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(context, '本週新泡泡'),
        const SizedBox(height: 10),
        productsMapAsync.when(
          data: (productsMap) {
            final all = productsMap.values.toList();
            if (all.isEmpty) {
              return _empty(context, '新上架：目前沒有資料');
            }

            // 新上架：盡量用 createdAt/updatedAt/publishedAt/order 來排序（沒有就 fallback）
            all.sort((a, b) => _newerFirst(a, b));
            final newest = all.take(10).toList();

            // 即將上架：先用「還沒上架」的欄位猜（若無欄位，就用次新清單當 placeholder）
            final coming = _comingSoonCandidates(all, max: 6);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _rail(context, newest, badge: 'NEW'),
                const SizedBox(height: 14),
                _titleSmall(context, '即將上架'),
                const SizedBox(height: 10),
                if (coming.isEmpty)
                  _empty(context, '即將上架：目前沒有資料（之後可加欄位精準控制）')
                else
                  _rail(context, coming, badge: 'SOON'),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 190,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => _empty(context, '新上架讀取錯誤：$e'),
        ),
      ],
    );
  }

  // ---------- sorting & data ----------

  int _newerFirst(Product a, Product b) {
    // fallback：用 id 字串
    return b.id.compareTo(a.id);
  }

  // 即將上架：如果未來你加上 comingSoon / releaseAt / published 等欄位，就會自動生效
  List<Product> _comingSoonCandidates(List<Product> sortedNewestFirst,
      {int max = 6}) {
    final soon = <Product>[];

    bool isComing(Product p) {
      // 嘗試幾種可能欄位（都不要求一定存在）
      try {
        final v = (p as dynamic).comingSoon;
        if (v is bool) return v == true;
      } catch (_) {}
      try {
        final v = (p as dynamic).published;
        if (v is bool) return v == false;
      } catch (_) {}
      try {
        final v = (p as dynamic).releaseAt;
        if (v is DateTime) return v.isAfter(DateTime.now());
      } catch (_) {}
      return false;
    }

    for (final p in sortedNewestFirst) {
      if (isComing(p)) soon.add(p);
      if (soon.length >= max) break;
    }

    // 沒欄位時先用次新（當 UI 占位）：避免空白感
    if (soon.isEmpty) {
      final fallback = sortedNewestFirst.skip(10).take(max).toList();
      return fallback;
    }
    return soon;
  }

  // ---------- UI ----------

  Widget _title(BuildContext context, String title) {
    final tokens = context.tokens;
    return Text('│ $title',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: tokens.textPrimary,
        ));
  }

  Widget _titleSmall(BuildContext context, String title) {
    final tokens = context.tokens;
    return Text(title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: tokens.textSecondary,
        ));
  }

  Widget _empty(BuildContext context, String text) {
    final tokens = context.tokens;
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(text, style: TextStyle(color: tokens.textSecondary)),
      ),
    );
  }

  Widget _rail(BuildContext context, List<Product> products,
      {required String badge}) {
    final tokens = context.tokens;
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final p = products[i];
          return SizedBox(
            width: 280,
            child: AppCard(
              padding: EdgeInsets.zero,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ProductPage(productId: p.id)),
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (p.coverImageUrl != null &&
                          p.coverImageUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20)),
                          child: Image.network(
                            p.coverImageUrl!,
                            height: 110,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 110,
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
                              Text(p.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: tokens.textPrimary)),
                              const SizedBox(height: 4),
                              Text('${p.topicId} · ${p.level}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: tokens.textSecondary,
                                      fontSize: 12)),
                              const Spacer(),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text('查看 ›',
                                    style: TextStyle(
                                        color: tokens.primary,
                                        fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Badge
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: tokens.primary.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18)),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
