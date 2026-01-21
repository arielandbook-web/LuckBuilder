import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class InboxItem {
  final String productId;
  final String contentItemId;
  final int whenMs; // 預計送達時間（排程時間）
  final String title;
  final String body;

  // 狀態
  final int? openedAtMs; // 使用者點開推播/補看
  final int? dismissedAtMs; // 使用者在收件匣標記已讀/略過

  const InboxItem({
    required this.productId,
    required this.contentItemId,
    required this.whenMs,
    required this.title,
    required this.body,
    this.openedAtMs,
    this.dismissedAtMs,
  });

  bool get isDismissed => dismissedAtMs != null;
  bool get isOpened => openedAtMs != null;

  InboxItem copyWith({
    int? openedAtMs,
    int? dismissedAtMs,
  }) {
    return InboxItem(
      productId: productId,
      contentItemId: contentItemId,
      whenMs: whenMs,
      title: title,
      body: body,
      openedAtMs: openedAtMs ?? this.openedAtMs,
      dismissedAtMs: dismissedAtMs ?? this.dismissedAtMs,
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'contentItemId': contentItemId,
        'whenMs': whenMs,
        'title': title,
        'body': body,
        'openedAtMs': openedAtMs,
        'dismissedAtMs': dismissedAtMs,
      };

  static InboxItem fromMap(Map<String, dynamic> m) => InboxItem(
        productId: (m['productId'] ?? '').toString(),
        contentItemId: (m['contentItemId'] ?? '').toString(),
        whenMs: (m['whenMs'] as num).toInt(),
        title: (m['title'] ?? '').toString(),
        body: (m['body'] ?? '').toString(),
        openedAtMs: (m['openedAtMs'] is num) ? (m['openedAtMs'] as num).toInt() : null,
        dismissedAtMs: (m['dismissedAtMs'] is num) ? (m['dismissedAtMs'] as num).toInt() : null,
      );
}

class NotificationInboxStore {
  static String _key(String uid) => 'lb_inbox_$uid';

  static Future<List<InboxItem>> load(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(uid));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<dynamic>();
      return list.map((e) => InboxItem.fromMap((e as Map).cast<String, dynamic>())).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(String uid, List<InboxItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toMap()).toList());
    await prefs.setString(_key(uid), encoded);
  }

  /// 把「未來 N 天排程」寫入收件匣（只覆蓋該時間窗的項目，不動舊的已過期/已讀）
  static Future<void> upsertWindow({
    required String uid,
    required int windowStartMs,
    required int windowEndMs,
    required List<InboxItem> scheduled,
  }) async {
    final all = await load(uid);

    // 保留：不在 window 的資料 + window 內已讀/已略過資料
    final kept = <InboxItem>[];
    for (final it in all) {
      final inWindow = it.whenMs >= windowStartMs && it.whenMs <= windowEndMs;
      if (!inWindow) {
        kept.add(it);
        continue;
      }
      // window 內已經 opened/dismissed 的保留
      if (it.isOpened || it.isDismissed) {
        kept.add(it);
      }
    }

    // window 內未讀資料：用 scheduled 覆蓋（以 productId+contentItemId 為 key）
    final map = <String, InboxItem>{};
    for (final it in kept) {
      map['${it.productId}::${it.contentItemId}'] = it;
    }
    for (final it in scheduled) {
      final key = '${it.productId}::${it.contentItemId}';
      // 若之前有 opened/dismissed 狀態，保留狀態
      final old = map[key];
      if (old != null && (old.isOpened || old.isDismissed)) {
        map[key] = it.copyWith(openedAtMs: old.openedAtMs, dismissedAtMs: old.dismissedAtMs);
      } else {
        map[key] = it;
      }
    }

    final next = map.values.toList()
      ..sort((a, b) => b.whenMs.compareTo(a.whenMs)); // 新的在前
    await save(uid, next);
  }

  static Future<void> markOpened({
    required String uid,
    required String productId,
    required String contentItemId,
  }) async {
    final all = await load(uid);
    final now = DateTime.now().millisecondsSinceEpoch;

    final next = all.map((it) {
      if (it.productId == productId && it.contentItemId == contentItemId) {
        return it.copyWith(openedAtMs: now);
      }
      return it;
    }).toList();

    await save(uid, next);
  }

  static Future<void> dismiss({
    required String uid,
    required String productId,
    required String contentItemId,
  }) async {
    final all = await load(uid);
    final now = DateTime.now().millisecondsSinceEpoch;

    final next = all.map((it) {
      if (it.productId == productId && it.contentItemId == contentItemId) {
        return it.copyWith(dismissedAtMs: now);
      }
      return it;
    }).toList();

    await save(uid, next);
  }

  static Future<void> clearAll(String uid) async {
    await save(uid, []);
  }
}
