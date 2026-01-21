import 'package:shared_preferences/shared_preferences.dart';

class UserStateStore {
  static const _kRecentSearches = 'recent_searches_v1';

  static const _kLastViewedTopicId = 'last_view_topic_id_v1';
  static const _kLastViewedDay = 'last_view_day_v1';
  static const _kLastViewedTitle = 'last_view_title_v1';

  static const _kTodayKey = 'today_key_v1';
  static const _kLearnedToday = 'learned_today_v1';

  Future<SharedPreferences> get _sp async => SharedPreferences.getInstance();

  // ---------- Search history ----------
  Future<List<String>> getRecentSearches() async {
    final sp = await _sp;
    return sp.getStringList(_kRecentSearches) ?? <String>[];
  }

  Future<void> addRecentSearch(String q) async {
    final cleaned = q.trim();
    if (cleaned.isEmpty) return;

    final sp = await _sp;
    final list = sp.getStringList(_kRecentSearches) ?? <String>[];
    final next = <String>[cleaned, ...list.where((e) => e != cleaned)];
    await sp.setStringList(_kRecentSearches, next.take(20).toList());
  }

  Future<void> clearRecentSearches() async {
    final sp = await _sp;
    await sp.remove(_kRecentSearches);
  }

  // ---------- Continue learning ----------
  Future<void> setContinueLearning({
    required String topicId,
    required int day,
    required String lastTitle,
  }) async {
    final sp = await _sp;
    await sp.setString(_kLastViewedTopicId, topicId);
    await sp.setInt(_kLastViewedDay, day);
    await sp.setString(_kLastViewedTitle, lastTitle);
  }

  Future<({String? topicId, int? day, String? lastTitle})>
      getContinueLearning() async {
    final sp = await _sp;
    return (
      topicId: sp.getString(_kLastViewedTopicId),
      day: sp.getInt(_kLastViewedDay),
      lastTitle: sp.getString(_kLastViewedTitle),
    );
  }

  // ---------- Today progress ----------
  String _todayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  Future<int> getLearnedToday() async {
    final sp = await _sp;
    final key = _todayKey();
    final savedKey = sp.getString(_kTodayKey);

    if (savedKey != key) {
      await sp.setString(_kTodayKey, key);
      await sp.setInt(_kLearnedToday, 0);
    }
    return sp.getInt(_kLearnedToday) ?? 0;
  }

  Future<void> incLearnedToday() async {
    final sp = await _sp;
    final now = await getLearnedToday();
    await sp.setInt(_kLearnedToday, now + 1);
  }
}
