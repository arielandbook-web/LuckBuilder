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
/// 
/// ⚠️ 已廢棄：此 Repository 已不再使用，請改用 V2Repository
/// 保留此類別僅供參考，未來可能會被移除
@Deprecated('請改用 V2Repository')
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
  // ✅ 處理 whereIn 的 10 個元素限制，分批查詢
  Future<List<Product>> fetchProductsByIdsOrdered(List<String> ids) async {
    try {
      if (ids.isEmpty) return [];

      final productsMap = <String, Product>{};
      const batchSize = 10; // Firestore whereIn 限制為 10 個元素
      
      // 分批查詢以處理 whereIn 限制
      for (var i = 0; i < ids.length; i += batchSize) {
        final batch = ids.skip(i).take(batchSize).toList();
        try {
          final snapshot = await _firestore
              .collection(Col.products)
              .where(FieldPath.documentId, whereIn: batch)
              .where(F.published, isEqualTo: true)
              .get();

          for (var doc in snapshot.docs) {
            productsMap[doc.id] = Product.fromDoc(doc.id, doc.data());
          }
        } catch (e) {
          debugPrint('Error fetching products batch: $e');
          // 繼續處理下一批
        }
      }

      // 按照原始順序返回產品
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

  // 根據內容文字搜尋產品（只搜尋預覽內容）- 客戶端過濾
  // ✅ 性能優化：一次性獲取所有預覽內容項，避免多次查詢
  Future<List<String>> searchProductsByContent(String query) async {
    try {
      if (query.isEmpty) return [];

      final queryLower = query.toLowerCase();
      final matchedProductIds = <String>{};

      // ✅ 一次性獲取所有預覽內容項（性能優化：減少 Firestore 查詢次數）
      final contentSnapshot = await _firestore
          .collection(Col.contentItems)
          .where(F.isPreview, isEqualTo: true)
          .get();

      // 在客戶端過濾包含搜索關鍵詞的內容項
      for (final contentDoc in contentSnapshot.docs) {
        final contentData = contentDoc.data();
        final content = (contentData['content'] ?? '').toString().toLowerCase();
        
        if (content.contains(queryLower)) {
          final productId = (contentData[F.productId] ?? '').toString();
          if (productId.isNotEmpty) {
            matchedProductIds.add(productId);
          }
        }
      }

      // ✅ 驗證匹配的產品是否已發布（確保權限控制）
      if (matchedProductIds.isEmpty) return [];
      
      // ✅ 處理 whereIn 的 10 個元素限制，分批查詢
      final matchedIdsList = matchedProductIds.toList();
      final publishedProductIds = <String>[];
      const batchSize = 10; // Firestore whereIn 限制為 10 個元素
      
      for (var i = 0; i < matchedIdsList.length; i += batchSize) {
        final batch = matchedIdsList.skip(i).take(batchSize).toList();
        try {
          final productsSnapshot = await _firestore
              .collection(Col.products)
              .where(FieldPath.documentId, whereIn: batch)
              .where(F.published, isEqualTo: true)
              .get();
          
          publishedProductIds.addAll(productsSnapshot.docs.map((doc) => doc.id));
        } catch (e) {
          debugPrint('Error fetching products batch: $e');
          // 繼續處理下一批
        }
      }

      return publishedProductIds;
    } catch (e) {
      debugPrint('Error searching products by content: $e');
      return [];
    }
  }

  // 獲取所有已發布產品 Map
  Future<Map<String, Product>> fetchAllProductsMap() async {
    try {
      final snapshot = await _firestore
          .collection(Col.products)
          .where(F.published, isEqualTo: true)
          .get();

      final map = <String, Product>{};
      for (final doc in snapshot.docs) {
        map[doc.id] = Product.fromDoc(doc.id, doc.data());
      }
      return map;
    } catch (e) {
      debugPrint('Error fetching all products map: $e');
      return {};
    }
  }

  // 獲取新上架產品（已上架：按 order 倒序）
  Future<List<Product>> fetchNewArrivals({int limit = 12}) async {
    try {
      final snapshot = await _firestore
          .collection(Col.products)
          .where(F.published, isEqualTo: true)
          .orderBy(F.order, descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => Product.fromDoc(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching new arrivals: $e');
      return [];
    }
  }

  // 獲取即將上架產品（未上架：按 order 倒序）
  Future<List<Product>> fetchUpcomingProducts({int limit = 8}) async {
    try {
      final snapshot = await _firestore
          .collection(Col.products)
          .where(F.published, isEqualTo: false)
          .orderBy(F.order, descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => Product.fromDoc(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching upcoming products: $e');
      return [];
    }
  }
}
