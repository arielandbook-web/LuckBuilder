import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DailyRoutine {
  final String? activeCollectionId;
  final List<String> orderedProductIds;
  final int updatedAtMs;

  const DailyRoutine({
    required this.activeCollectionId,
    required this.orderedProductIds,
    required this.updatedAtMs,
  });

  static DailyRoutine empty() => DailyRoutine(
        activeCollectionId: null,
        orderedProductIds: const [],
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );

  Map<String, dynamic> toJson() => {
        'activeCollectionId': activeCollectionId,
        'orderedProductIds': orderedProductIds,
        'updatedAtMs': updatedAtMs,
      };

  static DailyRoutine fromJson(Map<String, dynamic> j) => DailyRoutine(
        activeCollectionId: j['activeCollectionId']?.toString(),
        orderedProductIds: (j['orderedProductIds'] is List)
            ? (j['orderedProductIds'] as List).map((e) => e.toString()).toList()
            : <String>[],
        updatedAtMs: (j['updatedAtMs'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      );
}

class DailyRoutineStore {
  static const _prefix = 'daily_routine_v1_';
  static String _key(String uid) => '$_prefix$uid';

  static Future<DailyRoutine> load(String uid) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key(uid));
    if (raw == null || raw.isEmpty) return DailyRoutine.empty();
    try {
      return DailyRoutine.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return DailyRoutine.empty();
    }
  }

  static Future<void> save(String uid, DailyRoutine r) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key(uid), jsonEncode(r.toJson()));
  }

  static Future<void> clear(String uid) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key(uid));
  }
}
