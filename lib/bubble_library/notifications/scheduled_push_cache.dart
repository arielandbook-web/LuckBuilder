import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ScheduledPushEntry {
  final DateTime when;
  final String title;
  final String body;
  final Map<String, dynamic> payload;

  ScheduledPushEntry({
    required this.when,
    required this.title,
    required this.body,
    required this.payload,
  });

  Map<String, dynamic> toJson() => {
        'when': when.toIso8601String(),
        'title': title,
        'body': body,
        'payload': payload,
      };

  static ScheduledPushEntry fromJson(Map<String, dynamic> j) =>
      ScheduledPushEntry(
        when: DateTime.tryParse(j['when']?.toString() ?? '') ?? DateTime.now(),
        title: j['title']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        payload: (j['payload'] is Map)
            ? (j['payload'] as Map).map((k, v) => MapEntry(k.toString(), v))
            : <String, dynamic>{},
      );
}

class ScheduledPushCache {
  static const _k = 'scheduled_push_cache_v1';

  Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_k);
  }

  Future<void> add(ScheduledPushEntry e) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k);
    final list = raw == null ? <dynamic>[] : (jsonDecode(raw) as List<dynamic>);
    list.add(e.toJson());
    await sp.setString(_k, jsonEncode(list));
  }

  Future<List<ScheduledPushEntry>> loadSortedUpcoming({
    Duration horizon = const Duration(days: 3),
  }) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List<dynamic>)
        .whereType<Map>()
        .map((m) => ScheduledPushEntry.fromJson(
            m.map((k, v) => MapEntry(k.toString(), v))))
        .toList();

    final now = DateTime.now();
    final end = now.add(horizon);
    final filtered =
        list.where((e) => e.when.isAfter(now) && e.when.isBefore(end)).toList();
    filtered.sort((a, b) => a.when.compareTo(b.when));
    return filtered;
  }
}
