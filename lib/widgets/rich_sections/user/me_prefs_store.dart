import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MePrefsStore {
  static const _kTagsPrefix = 'me_interest_tags_';
  static const _kCustomTagsPrefix = 'me_custom_interest_tags_';

  static String _tagsKey(String uidOrLocal) => '$_kTagsPrefix$uidOrLocal';
  static String _customTagsKey(String uidOrLocal) =>
      '$_kCustomTagsPrefix$uidOrLocal';

  static Future<List<String>> getInterestTags(String uidOrLocal) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_tagsKey(uidOrLocal));
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return <String>[];
    }
  }

  static Future<void> setInterestTags(
      String uidOrLocal, List<String> tags) async {
    final sp = await SharedPreferences.getInstance();
    final cleaned = tags
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    await sp.setString(_tagsKey(uidOrLocal), jsonEncode(cleaned));
  }

  static Future<List<String>> getCustomTags(String uidOrLocal) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_customTagsKey(uidOrLocal));
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return <String>[];
    }
  }

  static Future<void> addCustomTag(String uidOrLocal, String tag) async {
    final t = tag.trim();
    if (t.isEmpty) return;

    final sp = await SharedPreferences.getInstance();
    final list = (await getCustomTags(uidOrLocal)).toSet();
    list.add(t);
    final out = list.toList()..sort();
    await sp.setString(_customTagsKey(uidOrLocal), jsonEncode(out));
  }

  static Future<void> removeCustomTag(String uidOrLocal, String tag) async {
    final sp = await SharedPreferences.getInstance();
    final set = (await getCustomTags(uidOrLocal)).toSet();
    set.remove(tag);
    final out = set.toList()..sort();
    await sp.setString(_customTagsKey(uidOrLocal), jsonEncode(out));
  }
}
