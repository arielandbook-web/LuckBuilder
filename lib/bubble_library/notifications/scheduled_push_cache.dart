import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ScheduledPushEntry {
  final DateTime when;
  final String title;
  final String body;
  final Map<String, dynamic> payload;
  final int? notificationId;

  ScheduledPushEntry({
    required this.when,
    required this.title,
    required this.body,
    required this.payload,
    this.notificationId,
  });

  Map<String, dynamic> toJson() => {
        'when': when.toIso8601String(),
        'title': title,
        'body': body,
        'payload': payload,
        if (notificationId != null) 'notificationId': notificationId,
      };

  static ScheduledPushEntry fromJson(Map<String, dynamic> j) =>
      ScheduledPushEntry(
        when: DateTime.tryParse(j['when']?.toString() ?? '') ?? DateTime.now(),
        title: j['title']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        payload: (j['payload'] is Map)
            ? (j['payload'] as Map).map((k, v) => MapEntry(k.toString(), v))
            : <String, dynamic>{},
        notificationId: j['notificationId'] != null
            ? (j['notificationId'] as num).toInt()
            : null,
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

  /// 移除指定的通知條目（根據 notificationId 或 contentItemId）
  Future<void> removeByNotificationId(int notificationId) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k);
    if (raw == null || raw.isEmpty) return;
    final list = (jsonDecode(raw) as List<dynamic>)
        .whereType<Map>()
        .toList();
    
    list.removeWhere((m) {
      final id = m['notificationId'];
      return id != null && (id as num).toInt() == notificationId;
    });
    
    await sp.setString(_k, jsonEncode(list));
  }

  /// 移除包含指定 contentItemId 的所有條目
  Future<void> removeByContentItemId(String contentItemId) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k);
    if (raw == null || raw.isEmpty) return;
    final list = (jsonDecode(raw) as List<dynamic>)
        .whereType<Map>()
        .toList();
    
    list.removeWhere((m) {
      final payload = m['payload'];
      if (payload is! Map) return false;
      final cid = payload['contentItemId']?.toString();
      return cid == contentItemId;
    });
    
    await sp.setString(_k, jsonEncode(list));
  }
}
