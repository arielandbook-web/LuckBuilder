import 'package:shared_preferences/shared_preferences.dart';

class SkipNextStore {
  static const _kPrefix = 'skip_next_v1_';

  static String _key(String uid) => '$_kPrefix$uid';

  static Future<Set<String>> load(String uid) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_key(uid)) ?? const <String>[];
    return list.toSet();
  }

  static Future<void> add(String uid, String contentItemId) async {
    final sp = await SharedPreferences.getInstance();
    final cur = (sp.getStringList(_key(uid)) ?? const <String>[]).toSet();
    cur.add(contentItemId);
    await sp.setStringList(_key(uid), cur.toList());
  }

  static Future<void> removeMany(String uid, Set<String> ids) async {
    if (ids.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    final cur = (sp.getStringList(_key(uid)) ?? const <String>[]).toSet();
    cur.removeAll(ids);
    await sp.setStringList(_key(uid), cur.toList());
  }

  static Future<void> clear(String uid) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key(uid));
  }
}
