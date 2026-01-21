import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 本機記錄「跳過下一則」：存 contentItemId，重排未來 N 天時略過
/// - 不動後端
/// - 有效期預設 4 天（涵蓋你 3 天排程窗口）
class PushSkipStore {
  static const _prefix = 'push_skip_v1_';

  static String _key(String uid) => '$_prefix$uid';

  /// 結構：{ productId: { contentItemId: expiresAtMillis } }
  static Future<Map<String, Map<String, int>>> getAll(String uid) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key(uid));
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final now = DateTime.now().millisecondsSinceEpoch;

      final out = <String, Map<String, int>>{};
      bool changed = false;

      for (final entry in decoded.entries) {
        final pid = entry.key;
        final inner = (entry.value as Map<String, dynamic>);

        final m = <String, int>{};
        for (final e in inner.entries) {
          final cid = e.key;
          final exp = (e.value as num).toInt();
          if (exp > now) {
            m[cid] = exp;
          } else {
            changed = true; // 過期清掉
          }
        }
        if (m.isNotEmpty) out[pid] = m;
      }

      if (changed) {
        await _save(uid, out);
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  static Future<void> skip({
    required String uid,
    required String productId,
    required String contentItemId,
    int ttlDays = 4,
  }) async {
    final all = await getAll(uid);
    final now = DateTime.now();
    final exp = now.add(Duration(days: ttlDays)).millisecondsSinceEpoch;

    final inner = all[productId] ?? <String, int>{};
    inner[contentItemId] = exp;
    all[productId] = inner;

    await _save(uid, all);
  }

  static Future<void> clearExpired(String uid) async {
    await getAll(uid); // getAll 會順便清掉
  }

  static Future<void> _save(
      String uid, Map<String, Map<String, int>> all) async {
    final sp = await SharedPreferences.getInstance();
    final jsonMap = <String, dynamic>{};
    for (final e in all.entries) {
      jsonMap[e.key] = e.value;
    }
    await sp.setString(_key(uid), jsonEncode(jsonMap));
  }
}
