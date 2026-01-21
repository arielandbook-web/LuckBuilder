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

// 本週新泡泡（已上架：order 倒序）
final newArrivalsProvider = FutureProvider<List<Product>>((ref) async {
  final snap = await FirebaseFirestore.instance
      .collection('products')
      .where('published', isEqualTo: true)
      .orderBy('order', descending: true)
      .limit(12)
      .get();

  return snap.docs.map((d) => Product.fromDoc(d.id, d.data())).toList();
});

// 即將上架（未上架：order 倒序）
final upcomingProductsProvider = FutureProvider<List<Product>>((ref) async {
  final snap = await FirebaseFirestore.instance
      .collection('products')
      .where('published', isEqualTo: false)
      .orderBy('order', descending: true)
      .limit(8)
      .get();

  return snap.docs.map((d) => Product.fromDoc(d.id, d.data())).toList();
});
