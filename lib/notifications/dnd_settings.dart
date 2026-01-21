import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DndSettings {
  final bool enabled;

  /// minutes since midnight
  final int startMin;
  final int endMin;

  const DndSettings({
    required this.enabled,
    required this.startMin,
    required this.endMin,
  });

  static const defaults =
      DndSettings(enabled: false, startMin: 22 * 60, endMin: 7 * 60);

  DndSettings copyWith({bool? enabled, int? startMin, int? endMin}) =>
      DndSettings(
        enabled: enabled ?? this.enabled,
        startMin: startMin ?? this.startMin,
        endMin: endMin ?? this.endMin,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'startMin': startMin,
        'endMin': endMin,
      };

  static DndSettings fromJson(Map<String, dynamic> j) => DndSettings(
        enabled: (j['enabled'] as bool?) ?? false,
        startMin: (j['startMin'] as num?)?.toInt() ?? 22 * 60,
        endMin: (j['endMin'] as num?)?.toInt() ?? 7 * 60,
      );
}

class DndSettingsStore {
  static const _prefix = 'dnd_v1_';
  static String _key(String uidOrLocal) => '$_prefix$uidOrLocal';

  static Future<DndSettings> load(String uidOrLocal) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key(uidOrLocal));
    if (raw == null || raw.isEmpty) return DndSettings.defaults;
    try {
      return DndSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return DndSettings.defaults;
    }
  }

  static Future<void> save(String uidOrLocal, DndSettings s) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key(uidOrLocal), jsonEncode(s.toJson()));
  }
}

/// ---- Time helpers ----
int timeOfDayToMin(TimeOfDay t) => t.hour * 60 + t.minute;
TimeOfDay minToTimeOfDay(int m) =>
    TimeOfDay(hour: (m ~/ 60) % 24, minute: m % 60);

String fmtTimeMin(int m) {
  final h = (m ~/ 60) % 24;
  final mm = m % 60;
  return '${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
}

/// ---- DND avoid logic ----
/// 支援跨午夜（例如 22:00–07:00）
bool isInDnd(DateTime dt, DndSettings s) {
  if (!s.enabled) return false;
  final cur = dt.hour * 60 + dt.minute;

  // not crossing midnight: start < end, e.g. 13:00–18:00
  if (s.startMin < s.endMin) {
    return cur >= s.startMin && cur < s.endMin;
  }
  // crossing midnight: start > end, e.g. 22:00–07:00
  return cur >= s.startMin || cur < s.endMin;
}

/// 回傳「落在勿擾內」的下一個可用時間點（通常是勿擾結束）
DateTime nextAllowed(DateTime dt, DndSettings s) {
  if (!isInDnd(dt, s)) return dt;

  final curMin = dt.hour * 60 + dt.minute;

  // start<end：同日 end
  if (s.startMin < s.endMin) {
    final end =
        DateTime(dt.year, dt.month, dt.day, s.endMin ~/ 60, s.endMin % 60);
    // 若剛好在 end 之前，回 end；否則回隔天 end（理論上不會進這裡）
    return end.isAfter(dt) ? end : end.add(const Duration(days: 1));
  }

  // 跨午夜：如果 cur 在 00:00~endMin 之間，回「今天 end」
  if (curMin < s.endMin) {
    return DateTime(dt.year, dt.month, dt.day, s.endMin ~/ 60, s.endMin % 60);
  }
  // 否則 cur 在 start~23:59，回「隔天 end」
  final tomorrow = dt.add(const Duration(days: 1));
  return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, s.endMin ~/ 60,
      s.endMin % 60);
}

/// 讓排程時間：
/// 1) 不落在勿擾
/// 2) 全部時間單調遞增（避免相同時間衝突）
DateTime adjustWhen({
  required DateTime original,
  required DndSettings s,
  DateTime? prev,
}) {
  var t = nextAllowed(original, s);

  // 保持單調遞增：至少比 prev 晚 1 分鐘
  if (prev != null && !t.isAfter(prev)) {
    t = prev.add(const Duration(minutes: 1));
  }

  // 若推到勿擾區裡，再推到下一個可用時間，並再次確保 > prev
  if (isInDnd(t, s)) {
    t = nextAllowed(t, s);
    if (prev != null && !t.isAfter(prev)) {
      t = prev.add(const Duration(minutes: 1));
      if (isInDnd(t, s)) t = nextAllowed(t, s);
    }
  }

  return t;
}
