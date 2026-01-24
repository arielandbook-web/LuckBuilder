import 'package:flutter/material.dart';

enum PushTimeMode { preset, custom }

enum PushContentMode { seq, mixNewReview, preferUnlearned, preferSaved }

class TimeRange {
  final TimeOfDay start; // inclusive
  final TimeOfDay end; // exclusive; can cross midnight
  const TimeRange(this.start, this.end);

  Map<String, dynamic> toMap() => {
        'start': {'h': start.hour, 'm': start.minute},
        'end': {'h': end.hour, 'm': end.minute},
      };

  factory TimeRange.fromMap(Map<String, dynamic>? m) {
    if (m == null) {
      return const TimeRange(
          TimeOfDay(hour: 22, minute: 0), TimeOfDay(hour: 8, minute: 0));
    }
    final s = (m['start'] as Map?)?.cast<String, dynamic>() ?? {};
    final e = (m['end'] as Map?)?.cast<String, dynamic>() ?? {};
    return TimeRange(
      TimeOfDay(
          hour: ((s['h'] ?? 22) as num).toInt(),
          minute: ((s['m'] ?? 0) as num).toInt()),
      TimeOfDay(
          hour: ((e['h'] ?? 8) as num).toInt(),
          minute: ((e['m'] ?? 0) as num).toInt()),
    );
  }
}

class PushConfig {
  final int freqPerDay; // 1..5
  final PushTimeMode timeMode;
  final List<String> presetSlots; // morning/noon/evening/night
  final List<TimeOfDay> customTimes; // 1..5
  final Set<int> daysOfWeek; // 1..7
  final int minIntervalMinutes; // e.g. 120
  final PushContentMode contentMode;

  const PushConfig({
    required this.freqPerDay,
    required this.timeMode,
    required this.presetSlots,
    required this.customTimes,
    required this.daysOfWeek,
    required this.minIntervalMinutes,
    required this.contentMode,
  });

  static PushConfig defaults() => const PushConfig(
        freqPerDay: 1,
        timeMode: PushTimeMode.preset,
        presetSlots: ['night'], // 預設睡前（最不打擾）
        customTimes: [],
        daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
        minIntervalMinutes: 120,
        contentMode: PushContentMode.seq,
      );

  Map<String, dynamic> toMap() => {
        'freqPerDay': freqPerDay,
        'timeMode': timeMode.name,
        'presetSlots': presetSlots,
        'customTimes':
            customTimes.map((t) => {'h': t.hour, 'm': t.minute}).toList(),
        'daysOfWeek': daysOfWeek.toList(),
        'minIntervalMinutes': minIntervalMinutes,
        'contentMode': contentMode.name,
      };

  factory PushConfig.fromMap(Map<String, dynamic>? m) {
    if (m == null) return PushConfig.defaults();
    final tm = (m['timeMode'] ?? 'preset') as String;
    final cm = (m['contentMode'] ?? 'seq') as String;

    final customTimes = (m['customTimes'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((x) => TimeOfDay(
              hour: ((x['h'] ?? 21) as num).toInt(),
              minute: ((x['m'] ?? 40) as num).toInt(),
            ))
        .toList();

    return PushConfig(
      freqPerDay: ((m['freqPerDay'] ?? 1) as num).toInt().clamp(1, 5),
      timeMode: PushTimeMode.values
          .firstWhere((e) => e.name == tm, orElse: () => PushTimeMode.preset),
      presetSlots: (m['presetSlots'] as List<dynamic>? ?? ['night'])
          .map((e) => e.toString())
          .toList(),
      customTimes: customTimes.take(5).toList(),
      daysOfWeek: (m['daysOfWeek'] as List<dynamic>? ?? [1, 2, 3, 4, 5, 6, 7])
          .map((e) => (e as num).toInt())
          .toSet(),
      minIntervalMinutes:
          ((m['minIntervalMinutes'] ?? 120) as num).toInt().clamp(30, 24 * 60),
      contentMode: PushContentMode.values
          .firstWhere((e) => e.name == cm, orElse: () => PushContentMode.seq),
    );
  }

  PushConfig copyWith({
    int? freqPerDay,
    PushTimeMode? timeMode,
    List<String>? presetSlots,
    List<TimeOfDay>? customTimes,
    Set<int>? daysOfWeek,
    int? minIntervalMinutes,
    PushContentMode? contentMode,
  }) {
    return PushConfig(
      freqPerDay: freqPerDay ?? this.freqPerDay,
      timeMode: timeMode ?? this.timeMode,
      presetSlots: presetSlots ?? this.presetSlots,
      customTimes: customTimes ?? this.customTimes,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      minIntervalMinutes: minIntervalMinutes ?? this.minIntervalMinutes,
      contentMode: contentMode ?? this.contentMode,
    );
  }
}
