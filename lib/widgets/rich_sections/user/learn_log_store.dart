import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LearnLogStore {
  static const _kPrefix = 'learn_days_';

  static String _key(String uidOrLocal) => '$_kPrefix$uidOrLocal';

  static String _yyyyMmDd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static Future<Set<String>> getLearnedDays(String uidOrLocal) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key(uidOrLocal));
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final list = (jsonDecode(raw) as List).cast<String>();
      return list.toSet();
    } catch (_) {
      return <String>{};
    }
  }

  /// 在「使用者真的有學習」的時候呼叫：例如打開內容頁 / 點「立即學 1 則」
  static Future<void> markLearnedToday(String uidOrLocal,
      {DateTime? now}) async {
    final sp = await SharedPreferences.getInstance();
    final set = await getLearnedDays(uidOrLocal);
    final today = _yyyyMmDd(now ?? DateTime.now());
    set.add(today);
    final out = set.toList()..sort();
    await sp.setString(_key(uidOrLocal), jsonEncode(out));
  }

  static int computeStreak(Set<String> days, {DateTime? now}) {
    if (days.isEmpty) return 0;
    final base = now ?? DateTime.now();
    int streak = 0;

    for (int i = 0; i < 3650; i++) {
      final dt =
          DateTime(base.year, base.month, base.day).subtract(Duration(days: i));
      final key = _yyyyMmDd(dt);
      if (days.contains(key)) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}
