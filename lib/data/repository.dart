import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'models.dart';

/// Firestore collection names (與 Console 一致：snake_case)
class Col {
  static const contentItems = 'content_items';
  static const featuredLists = 'featured_lists';
  static const products = 'products';
  static const topics = 'topics';
  static const ui = 'ui';
  static const segments = 'segments';
}

/// Firestore field names（避免拼錯）
class F {
  static const published = 'published';
  static const order = 'order';
  static const tags = 'tags';

  static const topicId = 'topicId';
  static const productId = 'productId';

  static const seq = 'seq';
  static const isPreview = 'isPreview';

  static const title = 'title';
  static const titleLower = 'titleLower';
}

/// V1 Repository
class DataRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 獲取所有已發布的區段，按 order 排序
  Future<List<Segment>> getSegments() async {
    try {
      final snapshot = await _firestore
          .collection(Col.segments)
          .where(F.published, isEqualTo: true)
          .orderBy(F.order)
          .get();

      return snapshot.docs
          .map((doc) => Segment.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      debugPrint('Error getting segments: $e');
      return [];
    }
  }

  // 獲取所有已發布的主題，按 order 排序
  Future<List<Topic>> getTopics() async {
    try {
      final snapshot = await _firestore
          .collection(Col.topics)
          .where(F.published, isEqualTo: true)
          .orderBy(F.order)
          .get();

      return snapshot.docs
          .map((doc) => Topic.fromDoc(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting topics: $e');
      return [];
    }
  }

  // 根據標籤獲取主題
  Future<List<Topic>> getTopicsByTag(String tag) async {
    try {
      final snapshot = await _firestore
          .collection(Col.topics)
          .where(F.published, isEqualTo: true)
          .where(F.tags, arrayContains: tag)
          .orderBy(F.order)
          .get();

      return snapshot.docs
          .map((doc) => Topic.fromDoc(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting topics by tag: $e');
      return [];
    }
  }

  // 獲取所有已發布的精選清單，按 order 排序
  Future<List<FeaturedList>> getFeaturedLists() async {
    try {
      final snapshot = await _firestore
          .collection(Col.featuredLists) // ✅ featured_lists
          .where(F.published, isEqualTo: true)
          .orderBy(F.order)
          .get();

      return snapshot.docs
          .map((doc) => FeaturedList.fromDoc(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting featured lists: $e');
      return [];
    }
  }

  // 根據 ID 獲取精選清單
  Future<FeaturedList?> getFeaturedListById(String id) async {
    try {
      final doc = await _firestore.collection(Col.featuredLists).doc(id).get();
      if (doc.exists) {
        return FeaturedList.fromDoc(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting featured list by id: $e');
      return null;
    }
  }

  // 獲取所有已發布的產品，按 order 排序
  Future<List<Product>> getProducts() async {
    try {
      final snapshot = await _firestore
          .collection(Col.products)
          .where(F.published, isEqualTo: true)
          .orderBy(F.order)
          .get();

      return snapshot.docs
          .map((doc) => Product.fromDoc(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting products: $e');
      return [];
    }
  }

  // 根據主題 ID 獲取產品
  Future<List<Product>> getProductsByTopicId(String topicId) async {
    try {
      final snapshot = await _firestore
          .collection(Col.products)
          .where(F.published, isEqualTo: true)
          .where(F.topicId, isEqualTo: topicId)
          .orderBy(F.order)
          .get();

      return snapshot.docs
          .map((doc) => Product.fromDoc(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting products by topic id: $e');
      return [];
    }
  }

  // 根據 ID 獲取產品
  Future<Product?> getProductById(String id) async {
    try {
      final doc = await _firestore.collection(Col.products).doc(id).get();
      if (doc.exists) {
        return Product.fromDoc(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting product by id: $e');
      return null;
    }
  }

  // 根據產品 ID 列表獲取多個產品
  Future<List<Product>> getProductsByIds(List<String> ids) async {
    try {
      if (ids.isEmpty) return [];

      final snapshot = await _firestore
          .collection(Col.products)
          .where(FieldPath.documentId, whereIn: ids)
          .where(F.published, isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => Product.fromDoc(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting products by ids: $e');
      return [];
    }
  }

  // 根據產品 ID 獲取內容項目，按 seq 排序
  Future<List<ContentItem>> getContentItemsByProductId(String productId) async {
    try {
      final snapshot = await _firestore
          .collection(Col.contentItems) // ✅ content_items
          .where(F.productId, isEqualTo: productId)
          .orderBy(F.seq)
          .get();

      return snapshot.docs
          .map((doc) => ContentItem.fromDoc(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting content items by product id: $e');
      return [];
    }
  }

  // 根據產品 ID 獲取預覽內容項目
  Future<List<ContentItem>> getPreviewContentItemsByProductId(
      String productId) async {
    try {
      final snapshot = await _firestore
          .collection(Col.contentItems)
          .where(F.productId, isEqualTo: productId)
          .where(F.isPreview, isEqualTo: true)
          .orderBy(F.seq)
          .get();

      return snapshot.docs
          .map((doc) => ContentItem.fromDoc(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting preview content items: $e');
      return [];
    }
  }

  // 根據 ID 獲取內容項目
  Future<ContentItem?> getContentItemById(String id) async {
    try {
      final doc = await _firestore.collection(Col.contentItems).doc(id).get();
      if (doc.exists) {
        return ContentItem.fromDoc(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting content item by id: $e');
      return null;
    }
  }
}

/// V2 Repository - 用於 Riverpod Providers
class V2Repository {
  final FirebaseFirestore _firestore;

  V2Repository(this._firestore);

  // 獲取所有已發布的區段，按 order 排序
  // 從 ui/segments_v1 文件讀取（與上傳腳本一致）
  Future<List<Segment>> fetchSegments() async {
    try {
      final doc = await _firestore.collection(Col.ui).doc('segments_v1').get();

      if (!doc.exists || doc.data() == null) {
        return [];
      }

      final data = doc.data()!;
      final segmentsList = data['segments'] as List<dynamic>?;

      if (segmentsList == null) {
        return [];
      }

      // 轉換為 Segment 物件，過濾已發布的，並排序
      final segments = segmentsList
          .map((item) => Segment.fromMap(item as Map<String, dynamic>))
          .where((s) => s.published)
          .toList();

      segments.sort((a, b) => a.order.compareTo(b.order));
      return segments;
    } catch (e) {
      debugPrint('Error fetching segments: $e');
      return [];
    }
  }

  // 根據區段獲取主題
  Future<List<Topic>> fetchTopicsForSegment(Segment segment) async {
    try {
      Query<Map<String, dynamic>> query =
          _firestore.collection(Col.topics).where(F.published, isEqualTo: true);

      if (segment.mode == 'tag' && segment.tag != null) {
        query = query.where(F.tags, arrayContains: segment.tag);
      }

      final snapshot = await query.orderBy(F.order).get();

      return snapshot.docs
          .map((doc) => Topic.fromDoc(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching topics for segment: $e');
      return [];
    }
  }

  // 根據 ID 獲取精選清單
  Future<FeaturedList?> fetchFeaturedList(String listId) async {
    try {
      final doc =
          await _firestore.collection(Col.featuredLists).doc(listId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data[F.published] == true) {
          return FeaturedList.fromDoc(doc.id, data);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching featured list: $e');
      return null;
    }
  }

  // 根據產品 ID 列表獲取產品，保持順序
  Future<List<Product>> fetchProductsByIdsOrdered(List<String> ids) async {
    try {
      if (ids.isEmpty) return [];

      final snapshot = await _firestore
          .collection(Col.products)
          .where(FieldPath.documentId, whereIn: ids)
          .where(F.published, isEqualTo: true)
          .get();

      final productsMap = {
        for (var doc in snapshot.docs)
          doc.id: Product.fromDoc(doc.id, doc.data())
      };

      return ids.map((id) => productsMap[id]).whereType<Product>().toList();
    } catch (e) {
      debugPrint('Error fetching products by ids ordered: $e');
      return [];
    }
  }

  // 根據主題 ID 獲取產品
  Future<List<Product>> fetchProductsByTopic(String topicId) async {
    try {
      final snapshot = await _firestore
          .collection(Col.products)
          .where(F.published, isEqualTo: true)
          .where(F.topicId, isEqualTo: topicId)
          .orderBy(F.order)
          .get();

      return snapshot.docs
          .map((doc) => Product.fromDoc(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching products by topic: $e');
      return [];
    }
  }

  // 根據 ID 獲取產品
  Future<Product?> fetchProduct(String productId) async {
    try {
      final doc =
          await _firestore.collection(Col.products).doc(productId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data[F.published] == true) {
          return Product.fromDoc(doc.id, data);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching product: $e');
      return null;
    }
  }

  // 獲取預覽內容項目（限制數量）
  Future<List<ContentItem>> fetchPreviewItems(
      String productId, int limit) async {
    try {
      final snapshot = await _firestore
          .collection(Col.contentItems)
          .where(F.productId, isEqualTo: productId)
          .where(F.isPreview, isEqualTo: true)
          .orderBy(F.seq)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ContentItem.fromDoc(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching preview items: $e');
      return [];
    }
  }

  // 根據前綴搜尋產品（標題）- 使用 titleLower 欄位進行不分大小寫搜尋
  Future<List<Product>> searchProductsPrefix(String query) async {
    try {
      if (query.isEmpty) return [];

      final queryLower = query.toLowerCase();

      final snapshot = await _firestore
          .collection(Col.products)
          .where(F.published, isEqualTo: true)
          .where(F.titleLower, isGreaterThanOrEqualTo: queryLower)
          .where(F.titleLower, isLessThan: '$queryLower\uf8ff')
          .orderBy(F.titleLower)
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => Product.fromDoc(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error searching products: $e');
      return [];
    }
  }
}
