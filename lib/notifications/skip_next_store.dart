import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SkipNextStore {
  static String _kGlobal(String uid) => 'skip_next_global_$uid';
  static String _kScoped(String uid, String productId) =>
      'skip_next_scoped_${uid}_$productId';

  static Future<Set<String>> load(String uid) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kGlobal(uid));
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final list = (jsonDecode(raw) as List).cast<String>();
      return list.toSet();
    } catch (_) {
      return <String>{};
    }
  }

  static Future<Set<String>> loadForProduct(String uid, String productId) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kScoped(uid, productId));
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final list = (jsonDecode(raw) as List).cast<String>();
      return list.toSet();
    } catch (_) {
      return <String>{};
    }
  }

  /// ✅ 加到「全域」skip（你 timeline 的 '跳過下一則' 可用這個）
  static Future<void> add(String uid, String contentItemId) async {
    final cur = await load(uid);
    cur.add(contentItemId);
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kGlobal(uid), jsonEncode(cur.toList()));
  }

  /// ✅ 加到「scoped」skip（若你之後要做：只跳過某商品的下一則）
  static Future<void> addForProduct(
      String uid, String productId, String contentItemId) async {
    final cur = await loadForProduct(uid, productId);
    cur.add(contentItemId);
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kScoped(uid, productId), jsonEncode(cur.toList()));
  }

  /// ✅ reschedule 時消耗（全域）
  static Future<void> removeMany(String uid, Set<String> ids) async {
    final cur = await load(uid);
    cur.removeAll(ids);
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kGlobal(uid), jsonEncode(cur.toList()));
  }

  /// ✅ reschedule 時消耗（scoped）
  static Future<void> removeManyForProduct(
      String uid, String productId, Set<String> ids) async {
    final cur = await loadForProduct(uid, productId);
    cur.removeAll(ids);
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kScoped(uid, productId), jsonEncode(cur.toList()));
  }
}
