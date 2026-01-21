class FirestorePaths {
  static String products() => 'products';
  static String contentItems() => 'content_items';

  static String userDoc(String uid) => 'users/$uid';
  static String userLibraryProducts(String uid) =>
      'users/$uid/library_products';
  static String userWishlist(String uid) => 'users/$uid/wishlist';
  static String userSavedItems(String uid) => 'users/$uid/saved_items';
  static String userGlobalPush(String uid) => 'users/$uid/push_settings/global';
}
