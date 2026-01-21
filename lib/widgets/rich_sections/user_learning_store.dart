import 'package:shared_preferences/shared_preferences.dart';

class UserLearningStore {
  static const _prefix = 'learned_v1';

  String _dayKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d'; // YYYYMMDD
  }

  String _key(String productId, String day) => '$_prefix:$productId:$day';

  /// 標記今天已學（對某個 product/topic）
  Future<void> markLearnedToday(String productId) async {
    final sp = await SharedPreferences.getInstance();
    final day = _dayKey(DateTime.now());
    await sp.setBool(_key(productId, day), true);
  }

  /// 取得過去 7 天（含今天）完成天數
  Future<int> weeklyCount(String productId) async {
    final sp = await SharedPreferences.getInstance();
    int count = 0;
    final now = DateTime.now();

    for (int i = 0; i < 7; i++) {
      final dt =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final day = _dayKey(dt);
      if (sp.getBool(_key(productId, day)) == true) count++;
    }
    return count;
  }

  // ========= 全域（跨所有 product） =========

  static const _globalPrefix = 'learned_global_v1';

  String _gKey(String day) => '$_globalPrefix:$day';

  /// 只要有學任何 topic，就同時標記全域今天已學
  Future<void> markGlobalLearnedToday() async {
    final sp = await SharedPreferences.getInstance();
    final day = _dayKey(DateTime.now());
    await sp.setBool(_gKey(day), true);
  }

  /// 全域：今天是否已完成
  Future<bool> globalLearnedToday() async {
    final sp = await SharedPreferences.getInstance();
    final day = _dayKey(DateTime.now());
    return sp.getBool(_gKey(day)) == true;
  }

  /// 全域：過去 7 天（含今天）完成天數
  Future<int> globalWeeklyCount() async {
    final sp = await SharedPreferences.getInstance();
    int count = 0;
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final dt =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final day = _dayKey(dt);
      if (sp.getBool(_gKey(day)) == true) count++;
    }
    return count;
  }

  /// 全域：連續天數 streak（從今天往回算，遇到中斷就停）
  Future<int> globalStreak() async {
    final sp = await SharedPreferences.getInstance();
    int streak = 0;
    final now = DateTime.now();

    for (int i = 0; i < 3650; i++) {
      final dt =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final day = _dayKey(dt);
      final ok = sp.getBool(_gKey(day)) == true;
      if (!ok) break;
      streak++;
    }
    return streak;
  }

  /// 建議你之後所有「學習入口」都呼叫這個
  Future<void> markLearnedTodayAndGlobal(String productId) async {
    await markLearnedToday(productId);
    await markGlobalLearnedToday();
  }
}
