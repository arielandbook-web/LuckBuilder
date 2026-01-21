import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 本機記錄「提醒我」的商品與時間
/// key: lb_coming_soon_remind_<uid>
/// value: json {"productId": 1700000000000(ms), ...}
class ComingSoonRemindStore {
  static String _key(String uid) => 'lb_coming_soon_remind_$uid';

  static Future<Map<String, int>> load(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(uid));
    if (raw == null || raw.isEmpty) return {};
    try {
      final obj = jsonDecode(raw) as Map<String, dynamic>;
      return obj.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> set({
    required String uid,
    required String productId,
    required int remindAtMs,
  }) async {
    final map = await load(uid);
    map[productId] = remindAtMs;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(uid), jsonEncode(map));
  }

  static Future<void> remove({
    required String uid,
    required String productId,
  }) async {
    final map = await load(uid);
    map.remove(productId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(uid), jsonEncode(map));
  }
}
