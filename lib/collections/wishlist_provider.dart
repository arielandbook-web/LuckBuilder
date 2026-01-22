import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bubble_library/providers/providers.dart';
import '../bubble_library/models/user_library.dart';
import '../bubble_library/data/library_repo.dart';

/// ✅ 統一使用 Firestore wishlistProvider，移除本地儲存
/// 為了向後兼容，保留 localWishlistProvider 名稱，但實際使用 Firestore
final localWishlistProvider = Provider<AsyncValue<List<WishlistItem>>>((ref) {
  return ref.watch(wishlistProvider);
});

/// 願望清單操作：統一使用 Firestore
class WishlistNotifier {
  final Ref ref;
  WishlistNotifier(this.ref);

  String get _uid => ref.read(uidProvider);
  LibraryRepo get _repo => ref.read(libraryRepoProvider);

  /// 重新整理（Firestore Stream 會自動更新，此方法保留用於向後兼容）
  Future<void> refresh() async {
    // Firestore Stream 會自動更新，不需要手動 refresh
  }

  /// 切換收藏（加入/移除願望清單）
  Future<void> toggleCollect(String productId) async {
    final wishlist = await ref.read(wishlistProvider.future);
    final exists = wishlist.any((w) => w.productId == productId);
    
    if (exists) {
      await _repo.removeWishlist(_uid, productId);
    } else {
      await _repo.addWishlist(_uid, productId);
    }
  }

  /// 移除願望清單
  Future<void> remove(String productId) async {
    await _repo.removeWishlist(_uid, productId);
  }

  /// 切換收藏狀態
  Future<void> toggleFavorite(String productId) async {
    final wishlist = await ref.read(wishlistProvider.future);
    final item = wishlist.firstWhere(
      (w) => w.productId == productId,
      orElse: () => throw StateError('Wishlist item not found: $productId'),
    );
    await _repo.setProductFavorite(_uid, productId, !item.isFavorite);
  }
}

/// ✅ 提供操作方法的 Provider（向後兼容 localWishlistProvider.notifier）
final localWishlistNotifierProvider = Provider<WishlistNotifier>((ref) {
  return WishlistNotifier(ref);
});
