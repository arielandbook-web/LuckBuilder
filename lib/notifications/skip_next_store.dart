import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 本機記錄：某 productId 的「下一則」要跳過的 contentItemId
/// key: lb_skip_next_<uid>
/// value: json {"productId":"contentItemId", ...}
class SkipNextStore {
  static String _key(String uid) => 'lb_skip_next_$uid';

  static Future<Map<String, String>> load(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(uid));
    if (raw == null || raw.isEmpty) return {};
    try {
      final obj = jsonDecode(raw) as Map<String, dynamic>;
      return obj.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> setSkip({
    required String uid,
    required String productId,
    required String contentItemId,
  }) async {
    final map = await load(uid);
    map[productId] = contentItemId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(uid), jsonEncode(map));
  }

  /// 清掉已使用的跳過（一次性）
  static Future<void> clearProducts({
    required String uid,
    required Iterable<String> productIds,
  }) async {
    final map = await load(uid);
    for (final pid in productIds) {
      map.remove(pid);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(uid), jsonEncode(map));
  }
}
