import 'push_config.dart';

class GlobalPushSettings {
  final bool enabled;
  final int dailyTotalCap; // 全 app 每日上限（跨產品）
  final TimeRange quietHours;
  final Set<int> daysOfWeek; // 1..7
  final String styleMode; // compact|standard|interactive

  const GlobalPushSettings({
    required this.enabled,
    required this.dailyTotalCap,
    required this.quietHours,
    required this.daysOfWeek,
    required this.styleMode,
  });

  static GlobalPushSettings defaults() => GlobalPushSettings(
        enabled: true,
        dailyTotalCap: 8,
        quietHours: TimeRange.fromMap(null), // 22:00-08:00
        daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
        styleMode: 'standard',
      );

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'dailyTotalCap': dailyTotalCap,
        'quietHours': quietHours.toMap(),
        'daysOfWeek': daysOfWeek.toList(),
        'styleMode': styleMode,
      };

  factory GlobalPushSettings.fromMap(Map<String, dynamic>? m) {
    if (m == null) return GlobalPushSettings.defaults();
    return GlobalPushSettings(
      enabled: (m['enabled'] ?? true) as bool,
      dailyTotalCap: ((m['dailyTotalCap'] ?? 8) as num).toInt().clamp(1, 50),
      quietHours: TimeRange.fromMap((m['quietHours'] as Map?)?.cast<String, dynamic>()),
      daysOfWeek: (m['daysOfWeek'] as List<dynamic>? ?? [1, 2, 3, 4, 5, 6, 7]).map((e) => (e as num).toInt()).toSet(),
      styleMode: (m['styleMode'] ?? 'standard') as String,
    );
  }

  GlobalPushSettings copyWith({
    bool? enabled,
    int? dailyTotalCap,
    TimeRange? quietHours,
    Set<int>? daysOfWeek,
    String? styleMode,
  }) {
    return GlobalPushSettings(
      enabled: enabled ?? this.enabled,
      dailyTotalCap: dailyTotalCap ?? this.dailyTotalCap,
      quietHours: quietHours ?? this.quietHours,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      styleMode: styleMode ?? this.styleMode,
    );
  }
}
