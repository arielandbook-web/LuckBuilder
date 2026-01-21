import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_library.dart';
import 'firestore_paths.dart';

class LibraryRepo {
  final FirebaseFirestore _db;
  LibraryRepo(this._db);

  Stream<List<UserLibraryProduct>> watchLibrary(String uid) {
    return _db
        .collection(FirestorePaths.userLibraryProducts(uid))
        .orderBy('purchasedAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => UserLibraryProduct.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<List<WishlistItem>> watchWishlist(String uid) {
    return _db
        .collection(FirestorePaths.userWishlist(uid))
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => WishlistItem.fromMap(d.id, d.data())).toList());
  }

  Stream<Map<String, SavedContent>> watchSaved(String uid) {
    return _db
        .collection(FirestorePaths.userSavedItems(uid))
        .snapshots()
        .map((s) {
      final map = <String, SavedContent>{};
      for (final d in s.docs) {
        map[d.id] = SavedContent.fromMap(d.id, d.data());
      }
      return map;
    });
  }

  Future<void> ensureLibraryProductExists({
    required String uid,
    required String productId,
    DateTime? purchasedAt,
  }) async {
    final ref =
        _db.collection(FirestorePaths.userLibraryProducts(uid)).doc(productId);
    final doc = await ref.get();
    if (doc.exists) return;

    await ref.set({
      'productId': productId,
      'purchasedAt': Timestamp.fromDate(purchasedAt ?? DateTime.now()),
      'isFavorite': false,
      'isHidden': false,
      'pushEnabled': false,
      'progress': {'nextSeq': 1, 'learnedCount': 0},
      'pushConfig': null,
      'lastOpenedAt': null,
    });
  }

  Future<void> setProductFavorite(String uid, String productId, bool v) async {
    await _db
        .collection(FirestorePaths.userLibraryProducts(uid))
        .doc(productId)
        .set(
      {'isFavorite': v},
      SetOptions(merge: true),
    );
    await _db.collection(FirestorePaths.userWishlist(uid)).doc(productId).set(
      {'isFavorite': v},
      SetOptions(merge: true),
    );
  }

  Future<void> hideProduct(String uid, String productId, bool hidden) async {
    await _db
        .collection(FirestorePaths.userLibraryProducts(uid))
        .doc(productId)
        .set(
      {'isHidden': hidden},
      SetOptions(merge: true),
    );
  }

  Future<void> setPushEnabled(
      String uid, String productId, bool enabled) async {
    await _db
        .collection(FirestorePaths.userLibraryProducts(uid))
        .doc(productId)
        .set(
      {'pushEnabled': enabled},
      SetOptions(merge: true),
    );
  }

  Future<void> setPushConfig(
      String uid, String productId, Map<String, dynamic> configMap) async {
    await _db
        .collection(FirestorePaths.userLibraryProducts(uid))
        .doc(productId)
        .set(
      {'pushConfig': configMap},
      SetOptions(merge: true),
    );
  }

  Future<void> touchLastOpened(String uid, String productId) async {
    await _db
        .collection(FirestorePaths.userLibraryProducts(uid))
        .doc(productId)
        .set(
      {'lastOpenedAt': Timestamp.now()},
      SetOptions(merge: true),
    );
  }

  Future<void> setSavedItem(
      String uid, String contentItemId, Map<String, dynamic> patch) async {
    await _db
        .collection(FirestorePaths.userSavedItems(uid))
        .doc(contentItemId)
        .set(
          patch,
          SetOptions(merge: true),
        );
  }

  Future<void> removeWishlist(String uid, String productId) async {
    await _db
        .collection(FirestorePaths.userWishlist(uid))
        .doc(productId)
        .delete();
  }

  Future<void> addWishlist(String uid, String productId) async {
    final ref = _db.collection(FirestorePaths.userWishlist(uid)).doc(productId);
    final doc = await ref.get();
    if (doc.exists) return;

    await ref.set({
      'productId': productId,
      'addedAt': Timestamp.now(),
      'isFavorite': false,
    });
  }
}
