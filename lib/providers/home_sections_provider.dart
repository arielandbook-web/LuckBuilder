import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models.dart';
import 'v2_providers.dart';

/// 統一首頁區塊的資料源
class HomeSectionsProvider {
  /// 新上架產品列表
  /// 優先順序：
  /// 1. autoNewArrivalsProvider（最近 7 天創建的）
  /// 2. featuredProductsProvider('new_arrivals')
  /// 3. allProductsMapProvider 的 newerFirst（按 createdAt 排序）
  static FutureProvider<List<Product>> newArrivalsProvider =
      FutureProvider<List<Product>>((ref) async {
    // 1. 優先使用 autoNewArrivalsProvider
    final autoNew = ref.watch(autoNewArrivalsProvider);
    if (autoNew.isNotEmpty) {
      return autoNew;
    }

    // 2. 其次使用 featuredProductsProvider('new_arrivals')
    final featuredAsync = ref.watch(featuredProductsProvider('new_arrivals'));
    return featuredAsync.maybeWhen(
      data: (products) {
        if (products.isNotEmpty) return products;
        // 3. Fallback: 從 allProductsMapProvider 取最新
        return _getNewerFirstFromAll(ref);
      },
      orElse: () => _getNewerFirstFromAll(ref),
    );
  });

  /// 即將上架產品列表
  /// 優先順序：
  /// 1. featuredProductsProvider('coming_soon')
  /// 2. allProductsMapProvider 的 comingSoon 判斷
  static FutureProvider<List<Product>> comingSoonProvider =
      FutureProvider<List<Product>>((ref) async {
    // 1. 優先使用 featuredProductsProvider('coming_soon')
    final featuredAsync = ref.watch(featuredProductsProvider('coming_soon'));
    return featuredAsync.maybeWhen(
      data: (products) {
        if (products.isNotEmpty) return products;
        // 2. Fallback: 從 allProductsMapProvider 判斷 coming soon
        return _getComingSoonFromAll(ref);
      },
      orElse: () => _getComingSoonFromAll(ref),
    );
  });

  /// 從 allProductsMapProvider 取得最新產品（按 createdAt 排序）
  static Future<List<Product>> _getNewerFirstFromAll(
      Ref ref) async {
    final allAsync = ref.watch(allProductsMapProvider);
    return allAsync.maybeWhen(
      data: (map) {
        final list = map.values.toList();
        // 按 createdAt 排序（新的在前）
        list.sort((a, b) {
          final aMs = a.createdAtMs ?? 0;
          final bMs = b.createdAtMs ?? 0;
          return bMs.compareTo(aMs);
        });
        // 去重（以 productId）
        final seen = <String>{};
        final result = <Product>[];
        for (final p in list) {
          if (!seen.contains(p.id)) {
            seen.add(p.id);
            result.add(p);
          }
        }
        return result.take(12).toList();
      },
      orElse: () => <Product>[],
    );
  }

  /// 從 allProductsMapProvider 判斷即將上架的產品
  static Future<List<Product>> _getComingSoonFromAll(Ref ref) async {
    final allAsync = ref.watch(allProductsMapProvider);
    return allAsync.maybeWhen(
      data: (map) {
        final now = DateTime.now();
        final coming = <Product>[];

        for (final p in map.values) {
          bool isComing = false;

          // 嘗試幾種可能欄位
          try {
            final v = (p as dynamic).comingSoon;
            if (v is bool && v == true) {
              isComing = true;
            }
          } catch (_) {}

          if (!isComing) {
            try {
              final v = (p as dynamic).published;
              if (v is bool && v == false) {
                isComing = true;
              }
            } catch (_) {}
          }

          if (!isComing && p.releaseAt != null) {
            if (p.releaseAt!.isAfter(now)) {
              isComing = true;
            }
          }

          if (isComing) {
            coming.add(p);
          }
        }

        // 排序：有 releaseAt 的按 releaseAt，否則按 order
        coming.sort((a, b) {
          if (a.releaseAt != null && b.releaseAt != null) {
            return a.releaseAt!.compareTo(b.releaseAt!);
          }
          if (a.releaseAt != null) return -1;
          if (b.releaseAt != null) return 1;
          // 都沒有 releaseAt，按 order（假設有 order 欄位）
          try {
            final aOrder = (a as dynamic).order as int? ?? 0;
            final bOrder = (b as dynamic).order as int? ?? 0;
            return bOrder.compareTo(aOrder);
          } catch (_) {
            return 0;
          }
        });

        // 去重（以 productId）
        final seen = <String>{};
        final result = <Product>[];
        for (final p in coming) {
          if (!seen.contains(p.id)) {
            seen.add(p.id);
            result.add(p);
          }
        }

        return result.take(8).toList();
      },
      orElse: () => <Product>[],
    );
  }
}
