import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteSentence {
  final String contentItemId;
  final String productId;
  final String productName;
  final String anchorGroup;
  final String anchor;
  final String content;
  final DateTime favoritedAt;

  FavoriteSentence({
    required this.contentItemId,
    required this.productId,
    required this.productName,
    required this.anchorGroup,
    required this.anchor,
    required this.content,
    required this.favoritedAt,
  });

  Map<String, dynamic> toJson() => {
        'contentItemId': contentItemId,
        'productId': productId,
        'productName': productName,
        'anchorGroup': anchorGroup,
        'anchor': anchor,
        'content': content,
        'favoritedAt': favoritedAt.toIso8601String(),
      };

  static FavoriteSentence fromJson(Map<String, dynamic> j) => FavoriteSentence(
        contentItemId: j['contentItemId']?.toString() ?? '',
        productId: j['productId']?.toString() ?? '',
        productName: j['productName']?.toString() ?? '',
        anchorGroup: j['anchorGroup']?.toString() ?? '',
        anchor: j['anchor']?.toString() ?? '',
        content: j['content']?.toString() ?? '',
        favoritedAt: DateTime.tryParse(j['favoritedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class FavoriteSentencesStore {
  static String _k(String uid) => 'favorite_sentences_$uid';

  /// 添加收藏（如果已存在則更新收藏時間）
  static Future<void> add(String uid, FavoriteSentence sentence) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k(uid));
    final list = raw == null
        ? <Map<String, dynamic>>[]
        : (jsonDecode(raw) as List<dynamic>)
            .whereType<Map>()
            .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
            .toList();

    // 檢查是否已存在，如果存在則移除舊的
    list.removeWhere((e) => e['contentItemId'] == sentence.contentItemId);

    // 添加新的（會按收藏時間排序）
    list.add(sentence.toJson());

    // 按收藏時間倒序排序（最新的在前）
    list.sort((a, b) {
      final aTime = DateTime.tryParse(a['favoritedAt']?.toString() ?? '') ??
          DateTime(0);
      final bTime = DateTime.tryParse(b['favoritedAt']?.toString() ?? '') ??
          DateTime(0);
      return bTime.compareTo(aTime);
    });

    await sp.setString(_k(uid), jsonEncode(list));
  }

  /// 移除收藏
  static Future<void> remove(String uid, String contentItemId) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k(uid));
    if (raw == null || raw.isEmpty) return;

    final list = (jsonDecode(raw) as List<dynamic>)
        .whereType<Map>()
        .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
        .toList();

    list.removeWhere((e) => e['contentItemId'] == contentItemId);

    await sp.setString(_k(uid), jsonEncode(list));
  }

  /// 載入所有收藏（按收藏日期倒序）
  static Future<List<FavoriteSentence>> loadAll(String uid) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k(uid));
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .whereType<Map>()
          .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
          .map((m) => FavoriteSentence.fromJson(m))
          .toList();

      // 按收藏時間倒序排序（最新的在前）
      list.sort((a, b) => b.favoritedAt.compareTo(a.favoritedAt));

      return list;
    } catch (e) {
      return [];
    }
  }

  /// 檢查是否已收藏
  static Future<bool> isFavorited(String uid, String contentItemId) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k(uid));
    if (raw == null || raw.isEmpty) return false;

    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .whereType<Map>()
          .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
          .toList();

      return list.any((e) => e['contentItemId'] == contentItemId);
    } catch (_) {
      return false;
    }
  }
}
