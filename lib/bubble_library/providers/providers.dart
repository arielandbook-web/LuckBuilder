import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/product_repo.dart';
import '../data/content_repo.dart';
import '../data/library_repo.dart';
import '../data/push_settings_repo.dart';

import '../models/product.dart';
import '../models/content_item.dart';
import '../models/user_library.dart';
import '../models/global_push_settings.dart';

final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final uidProvider = Provider<String>((ref) {
  final u = ref.watch(firebaseAuthProvider).currentUser;
  if (u == null) throw StateError('User not logged in');
  return u.uid;
});

final productRepoProvider =
    Provider<ProductRepo>((ref) => ProductRepo(ref.watch(firestoreProvider)));
final contentRepoProvider =
    Provider<ContentRepo>((ref) => ContentRepo(ref.watch(firestoreProvider)));
final libraryRepoProvider =
    Provider<LibraryRepo>((ref) => LibraryRepo(ref.watch(firestoreProvider)));
final pushSettingsRepoProvider = Provider<PushSettingsRepo>(
    (ref) => PushSettingsRepo(ref.watch(firestoreProvider)));

final productsMapProvider = FutureProvider<Map<String, Product>>((ref) async {
  return ref.read(productRepoProvider).getAll();
});

final libraryProductsProvider = StreamProvider<List<UserLibraryProduct>>((ref) {
  final uid = ref.watch(uidProvider);
  return ref.read(libraryRepoProvider).watchLibrary(uid);
});

final wishlistProvider = StreamProvider<List<WishlistItem>>((ref) {
  final uid = ref.watch(uidProvider);
  return ref.read(libraryRepoProvider).watchWishlist(uid);
});

final savedItemsProvider = StreamProvider<Map<String, SavedContent>>((ref) {
  final uid = ref.watch(uidProvider);
  return ref.read(libraryRepoProvider).watchSaved(uid);
});

final globalPushSettingsProvider = StreamProvider<GlobalPushSettings>((ref) {
  final uid = ref.watch(uidProvider);
  return ref.read(pushSettingsRepoProvider).watchGlobal(uid);
});

final contentByProductProvider =
    FutureProvider.family<List<ContentItem>, String>((ref, productId) async {
  return ref.read(contentRepoProvider).getByProduct(productId);
});

final contentItemProvider =
    FutureProvider.family<ContentItem, String>((ref, contentItemId) async {
  return ref.read(contentRepoProvider).getOne(contentItemId);
});
