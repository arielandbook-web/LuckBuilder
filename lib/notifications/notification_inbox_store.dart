import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum InboxStatus { scheduled, missed, opened, skipped }

class InboxItem {
  final String uid;
  final String productId;
  final String contentItemId;
  final int whenMs;
  final String title;
  final String body;
  final InboxStatus status;
  final int updatedAtMs;

  InboxItem({
    required this.uid,
    required this.productId,
    required this.contentItemId,
    required this.whenMs,
    required this.title,
    required this.body,
    required this.status,
    required this.updatedAtMs,
  });

  String get key => '$productId::$contentItemId::$whenMs';

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'productId': productId,
        'contentItemId': contentItemId,
        'whenMs': whenMs,
        'title': title,
        'body': body,
        'status': status.name,
        'updatedAtMs': updatedAtMs,
      };

  static InboxItem fromMap(Map<String, dynamic> m) => InboxItem(
        uid: m['uid'] as String,
        productId: m['productId'] as String,
        contentItemId: m['contentItemId'] as String,
        whenMs: (m['whenMs'] as num).toInt(),
        title: (m['title'] ?? '') as String,
        body: (m['body'] ?? '') as String,
        status: InboxStatus.values.firstWhere(
          (e) => e.name == (m['status'] ?? 'scheduled'),
          orElse: () => InboxStatus.scheduled,
        ),
        updatedAtMs: (m['updatedAtMs'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      );
}

class NotificationInboxStore {
  static String _k(String uid) => 'notif_inbox_$uid';
  static String _kLastSweep(String uid) => 'notif_inbox_last_sweep_$uid';

  static Future<List<InboxItem>> load(String uid) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k(uid));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List)
          .cast<Map>()
          .map((e) => InboxItem.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(String uid, List<InboxItem> items) async {
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((e) => e.toMap()).toList());
    await sp.setString(_k(uid), raw);
  }

  /// ✅ 排程時寫入/更新（status=scheduled）
  static Future<void> upsertScheduled({
    required String uid,
    required String productId,
    required String contentItemId,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final items = await load(uid);

    final newItem = InboxItem(
      uid: uid,
      productId: productId,
      contentItemId: contentItemId,
      whenMs: when.millisecondsSinceEpoch,
      title: title,
      body: body,
      status: InboxStatus.scheduled,
      updatedAtMs: now,
    );

    final idx = items.indexWhere((e) => e.key == newItem.key);
    if (idx >= 0) {
      // 如果已存在，不覆蓋 opened / skipped，只更新 title/body/when
      final old = items[idx];
      final keepStatus = (old.status == InboxStatus.opened ||
              old.status == InboxStatus.skipped)
          ? old.status
          : InboxStatus.scheduled;

      items[idx] = InboxItem(
        uid: uid,
        productId: productId,
        contentItemId: contentItemId,
        whenMs: newItem.whenMs,
        title: title,
        body: body,
        status: keepStatus,
        updatedAtMs: now,
      );
    } else {
      items.add(newItem);
    }

    // 保留最近 500 筆（避免無限長）
    items.sort((a, b) => b.whenMs.compareTo(a.whenMs));
    final clipped = items.take(500).toList();
    await _save(uid, clipped);
  }

  /// ✅ 使用者點通知 or 補看 → 標記 opened
  static Future<void> markOpened(
    String uid, {
    required String productId,
    required String contentItemId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final items = await load(uid);

    // 找最近的一筆同 product+content
    int best = -1;
    int bestWhen = -1;
    for (int i = 0; i < items.length; i++) {
      final it = items[i];
      if (it.productId == productId && it.contentItemId == contentItemId) {
        if (it.whenMs > bestWhen) {
          bestWhen = it.whenMs;
          best = i;
        }
      }
    }
    if (best < 0) return;

    final old = items[best];
    items[best] = InboxItem(
      uid: old.uid,
      productId: old.productId,
      contentItemId: old.contentItemId,
      whenMs: old.whenMs,
      title: old.title,
      body: old.body,
      status: InboxStatus.opened,
      updatedAtMs: now,
    );

    await _save(uid, items);
  }

  /// ✅ App 回前景時：把「時間已過但未 opened」的 scheduled → missed
  static Future<void> sweepMissed(String uid) async {
    final sp = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final last = sp.getInt(_kLastSweep(uid)) ?? 0;
    // 防止每幀狂掃：10 秒內不重掃
    if (nowMs - last < 10 * 1000) return;

    final items = await load(uid);
    bool changed = false;

    for (int i = 0; i < items.length; i++) {
      final it = items[i];
      if (it.status == InboxStatus.scheduled && it.whenMs <= nowMs) {
        items[i] = InboxItem(
          uid: it.uid,
          productId: it.productId,
          contentItemId: it.contentItemId,
          whenMs: it.whenMs,
          title: it.title,
          body: it.body,
          status: InboxStatus.missed,
          updatedAtMs: nowMs,
        );
        changed = true;
      }
    }

    if (changed) {
      items.sort((a, b) => b.whenMs.compareTo(a.whenMs));
      await _save(uid, items);
    }
    await sp.setInt(_kLastSweep(uid), nowMs);
  }

  static Future<void> clearAll(String uid) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_k(uid));
  }

  static Future<void> clearMissed(String uid) async {
    final items = await load(uid);
    final kept = items.where((e) => e.status != InboxStatus.missed).toList();
    await _save(uid, kept);
  }
}
