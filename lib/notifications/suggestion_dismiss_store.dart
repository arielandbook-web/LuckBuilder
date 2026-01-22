import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SuggestionDismissStore {
  static String _k(String uid) => 'smart_suggest_dismiss_v1_$uid';

  static Future<Map<String, int>> _loadMap(String uid) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k(uid));
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return m.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveMap(String uid, Map<String, int> m) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_k(uid), jsonEncode(m));
  }

  /// 是否已被 dismiss（尚未過期）
  static Future<bool> isDismissed(String uid, String suggestionId) async {
    final m = await _loadMap(uid);
    final untilMs = m[suggestionId] ?? 0;
    return DateTime.now().millisecondsSinceEpoch < untilMs;
  }

  /// dismiss N 天（預設 3 天）
  static Future<void> dismiss(
    String uid,
    String suggestionId, {
    int days = 3,
  }) async {
    final m = await _loadMap(uid);
    final until = DateTime.now()
        .add(Duration(days: days))
        .millisecondsSinceEpoch;
    m[suggestionId] = until;
    await _saveMap(uid, m);
  }
}
