import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/repository.dart';
import '../data/models.dart';

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final v2RepoProvider =
    Provider<V2Repository>((ref) => V2Repository(ref.watch(firestoreProvider)));

final segmentsProvider = FutureProvider<List<Segment>>((ref) async {
  return ref.watch(v2RepoProvider).fetchSegments();
});

final selectedSegmentProvider = StateProvider<Segment?>((ref) => null);

final topicsForSelectedSegmentProvider =
    FutureProvider<List<Topic>>((ref) async {
  final repo = ref.watch(v2RepoProvider);
  final segs = await ref.watch(segmentsProvider.future);
  final selected = ref.watch(selectedSegmentProvider);
  final seg = selected ?? (segs.isNotEmpty ? segs.first : null);
  if (seg == null) return [];
  if (selected == null) ref.read(selectedSegmentProvider.notifier).state = seg;
  return repo.fetchTopicsForSegment(seg);
});

final featuredProductsProvider =
    FutureProvider.family<List<Product>, String>((ref, listId) async {
  final repo = ref.watch(v2RepoProvider);
  final list = await repo.fetchFeaturedList(listId);
  if (list == null) return [];
  return repo.fetchProductsByIdsOrdered(list.productIds);
});

final bannerProductsProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.watch(v2RepoProvider);
  final list = await repo.fetchFeaturedList('home_banners');
  if (list == null) return [];
  return repo.fetchProductsByIdsOrdered(list.productIds.take(3).toList());
});

/// coming soon 的 productId set（由 featured_lists/coming_soon 產生）
final comingSoonIdsProvider = Provider<Set<String>>((ref) {
  final async = ref.watch(featuredProductsProvider('coming_soon'));
  return async.maybeWhen(
    data: (ps) => ps.map((e) => e.id).toSet(),
    orElse: () => <String>{},
  );
});

final productsByTopicProvider =
    FutureProvider.family<List<Product>, String>((ref, topicId) async {
  return ref.watch(v2RepoProvider).fetchProductsByTopic(topicId);
});

final productProvider =
    FutureProvider.family<Product?, String>((ref, productId) async {
  return ref.watch(v2RepoProvider).fetchProduct(productId);
});

final previewItemsProvider =
    FutureProvider.family<List<ContentItem>, String>((ref, productId) async {
  final repo = ref.watch(v2RepoProvider);
  final p = await ref.watch(productProvider(productId).future);
  return repo.fetchPreviewItems(productId, p?.trialLimit ?? 3);
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<Product>>((ref) async {
  final q = ref.watch(searchQueryProvider);
  return ref.watch(v2RepoProvider).searchProductsPrefix(q);
});

enum SearchOwnedFilter { all, purchased, notPurchased }
enum SearchPushFilter { all, pushingOnly }
enum SearchWishFilter { all, wishedOnly }
enum SearchLevelFilter { all, l1, l2, l3, l4, l5, l6 }

final searchOwnedFilterProvider =
    StateProvider<SearchOwnedFilter>((ref) => SearchOwnedFilter.all);

final searchPushFilterProvider =
    StateProvider<SearchPushFilter>((ref) => SearchPushFilter.all);

final searchWishFilterProvider =
    StateProvider<SearchWishFilter>((ref) => SearchWishFilter.all);

final searchLevelFilterProvider =
    StateProvider<SearchLevelFilter>((ref) => SearchLevelFilter.all);

// 全部產品 Map（使用 lib/data/models.dart 的 Product，有 topicId）
// ✅ 已改為透過 V2Repository 控管
final allProductsMapProvider =
    FutureProvider<Map<String, Product>>((ref) async {
  return ref.watch(v2RepoProvider).fetchAllProductsMap();
});

final autoNewArrivalsProvider = Provider<List<Product>>((ref) {
  final allAsync = ref.watch(allProductsMapProvider);
  return allAsync.maybeWhen(
    data: (map) {
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 7));
      final list = map.values
          .where((p) => p.createdAt != null && p.createdAt!.isAfter(from))
          .toList();
      list.sort((a, b) => (b.createdAtMs ?? 0).compareTo(a.createdAtMs ?? 0));
      return list;
    },
    orElse: () => <Product>[],
  );
});

// 本週新泡泡（已上架：order 倒序）
// ✅ 已改為透過 V2Repository 控管
final newArrivalsProvider = FutureProvider<List<Product>>((ref) async {
  return ref.watch(v2RepoProvider).fetchNewArrivals(limit: 12);
});

// 即將上架（未上架：order 倒序）
// ✅ 已改為透過 V2Repository 控管
final upcomingProductsProvider = FutureProvider<List<Product>>((ref) async {
  return ref.watch(v2RepoProvider).fetchUpcomingProducts(limit: 8);
});
