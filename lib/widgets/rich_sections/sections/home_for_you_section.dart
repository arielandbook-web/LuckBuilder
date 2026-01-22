import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_tokens.dart';
import '../../app_card.dart';

import '../../../providers/v2_providers.dart';
import '../../../bubble_library/providers/providers.dart';
import '../../../collections/wishlist_provider.dart';
import '../../../data/models.dart';
import '../../../pages/product_page.dart';

class HomeForYouSection extends ConsumerWidget {
  const HomeForYouSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;

    // 如果未登入：直接用熱門補（避免 uidProvider throw）
    bool loggedIn = true;
    try {
      ref.read(uidProvider);
    } catch (_) {
      loggedIn = false;
    }

    final hotAsync = ref.watch(featuredProductsProvider('hot_all'));

    final libAsync = loggedIn
        ? ref.watch(libraryProductsProvider)
        : const AsyncValue.data(<dynamic>[]);
    final wishAsync = loggedIn
        ? ref.watch(localWishlistProvider)
        : const AsyncValue.data(<dynamic>[]);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('為你推薦',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: tokens.textPrimary)),
          const SizedBox(height: 10),
          hotAsync.when(
            data: (hotList) {
              return libAsync.when(
                data: (lib) {
                  return wishAsync.when(
                    data: (wish) {
                      final picks = _buildPicks(
                        lib: lib,
                        wish: wish,
                        hot: hotList,
                      );

                      if (picks.isEmpty) {
                        return Text('目前還沒有可推薦的內容',
                            style: TextStyle(color: tokens.textSecondary));
                      }

                      return SizedBox(
                        height: 190,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: picks.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (_, i) {
                            final p = picks[i];
                            return _ForYouCard(product: p);
                          },
                        ),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('wishlist error: $e',
                        style: TextStyle(color: tokens.textSecondary)),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('library error: $e',
                    style: TextStyle(color: tokens.textSecondary)),
              );
            },
            loading: () => const SizedBox(
                height: 190, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('hot error: $e',
                style: TextStyle(color: tokens.textSecondary)),
          ),
        ],
      ),
    );
  }

  List<Product> _buildPicks({
    required List<dynamic> lib,
    required List<dynamic> wish,
    required List<Product> hot,
  }) {
    // 建立 hot map 方便查找
    final hotMap = <String, Product>{for (final p in hot) p.id: p};

    final result = <Product>[];
    final used = <String>{};

    void addById(String pid) {
      if (used.contains(pid)) return;
      final p = hotMap[pid];
      if (p == null) return; // 只能顯示 hot list 裡有的
      used.add(pid);
      result.add(p);
    }

    // 1) 推播中（在 hot list 內的才顯示）
    for (final lp in lib) {
      if (_bool(lp, 'isHidden') == true) continue;
      if (_bool(lp, 'pushEnabled') == true) {
        final pid = _str(lp, 'productId');
        if (pid != null) addById(pid);
      }
    }

    // 2) 最愛（已購買 + 願望清單）
    for (final lp in lib) {
      if (_bool(lp, 'isHidden') == true) continue;
      if (_bool(lp, 'isFavorite') == true) {
        final pid = _str(lp, 'productId');
        if (pid != null) addById(pid);
      }
    }
    for (final w in wish) {
      if (_bool(w, 'isFavorite') == true) {
        final pid = _str(w, 'productId');
        if (pid != null) addById(pid);
      }
    }

    // 3) 最近開啟（lastOpenedAt / purchasedAt fallback）
    final libVisible = lib.where((lp) {
      if (_bool(lp, 'isHidden') == true) return false;
      final pid = _str(lp, 'productId');
      return pid != null && hotMap.containsKey(pid);
    }).toList();

    libVisible.sort((a, b) {
      final ta = _dt(a, 'lastOpenedAt') ??
          _dt(a, 'purchasedAt') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final tb = _dt(b, 'lastOpenedAt') ??
          _dt(b, 'purchasedAt') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });

    for (final lp in libVisible.take(3)) {
      final pid = _str(lp, 'productId');
      if (pid != null) addById(pid);
    }

    // 4) 願望清單（未購買收藏）
    for (final w in wish) {
      final pid = _str(w, 'productId');
      if (pid != null) addById(pid);
    }

    // 5) 不夠 → 熱門補滿
    for (final p in hot) {
      if (used.contains(p.id)) continue;
      used.add(p.id);
      result.add(p);
      if (result.length >= 6) break;
    }

    // 只顯示 6 個就好（首頁不宜過長）
    return result.take(6).toList();
  }

  // ====== small safe helpers (avoid model version mismatch) ======
  String? _str(dynamic obj, String field) {
    try {
      final v = (obj as dynamic).__get(field);
      if (v is String && v.isNotEmpty) return v;
    } catch (_) {}
    try {
      final v = (obj as dynamic).toMap()[field];
      if (v is String && v.isNotEmpty) return v;
    } catch (_) {}
    try {
      final v = (obj as dynamic).productId;
      if (field == 'productId' && v is String) return v;
    } catch (_) {}
    return null;
  }

  bool? _bool(dynamic obj, String field) {
    try {
      final m = (obj as dynamic).toMap();
      final v = m[field];
      if (v is bool) return v;
    } catch (_) {}
    try {
      final v = (obj as dynamic).__get(field);
      if (v is bool) return v;
    } catch (_) {}
    try {
      if (field == 'isHidden') return (obj as dynamic).isHidden as bool?;
      if (field == 'pushEnabled') return (obj as dynamic).pushEnabled as bool?;
      if (field == 'isFavorite') return (obj as dynamic).isFavorite as bool?;
    } catch (_) {}
    return null;
  }

  DateTime? _dt(dynamic obj, String field) {
    try {
      final m = (obj as dynamic).toMap();
      final v = m[field];
      if (v is DateTime) return v;
    } catch (_) {}
    try {
      if (field == 'lastOpenedAt') {
        return (obj as dynamic).lastOpenedAt as DateTime?;
      }
      if (field == 'purchasedAt') {
        return (obj as dynamic).purchasedAt as DateTime?;
      }
    } catch (_) {}
    return null;
  }
}

class _ForYouCard extends StatelessWidget {
  final Product product;
  const _ForYouCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SizedBox(
      width: 280,
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProductPage(productId: product.id),
        )),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.coverImageUrl != null &&
                product.coverImageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.network(
                  product.coverImageUrl!,
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
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: tokens.textPrimary)),
                    const SizedBox(height: 4),
                    Text('${product.topicId} · ${product.level}',
                        style: TextStyle(
                            color: tokens.textSecondary, fontSize: 11)),
                    const Spacer(),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text('查看 ›',
                          style: TextStyle(
                              color: tokens.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
