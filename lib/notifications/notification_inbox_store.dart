import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 收件匣項目狀態
enum InboxStatus {
  scheduled, // 已排程（未來）
  missed,    // 錯過（已過期但未開啟）
  opened,    // 已開啟
  skipped,   // 已跳過
}

/// 收件匣項目
class InboxItem {
  final String productId;
  final String contentItemId;
  final int whenMs; // 排程時間（毫秒）
  final String title;
  final String body;
  final InboxStatus status;

  InboxItem({
    required this.productId,
    required this.contentItemId,
    required this.whenMs,
    required this.title,
    required this.body,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'contentItemId': contentItemId,
        'whenMs': whenMs,
        'title': title,
        'body': body,
        'status': status.name,
      };

  static InboxItem fromJson(Map<String, dynamic> j) => InboxItem(
        productId: j['productId']?.toString() ?? '',
        contentItemId: j['contentItemId']?.toString() ?? '',
        whenMs: (j['whenMs'] as num?)?.toInt() ?? 0,
        title: j['title']?.toString() ?? '',
        body: j['body']?.toString() ?? '',
        status: _parseStatus(j['status']?.toString()),
      );

  static InboxStatus _parseStatus(String? s) {
    switch (s) {
      case 'scheduled':
        return InboxStatus.scheduled;
      case 'missed':
        return InboxStatus.missed;
      case 'opened':
        return InboxStatus.opened;
      case 'skipped':
        return InboxStatus.skipped;
      default:
        return InboxStatus.missed;
    }
  }
}

/// 通知收件匣：已讀(Opened) 本機紀錄
///
/// - 全域 opened（不分商品）：key = inbox_opened_<uid>
/// - 商品 scoped opened：key = inbox_opened_<uid>_<productId>
/// - 排程項目：key = inbox_scheduled_<uid>
/// - 錯過項目：key = inbox_missed_<uid>
///
/// value: {"<contentItemId>": <openedAtMs>, ...}
class NotificationInboxStore {
  static String _kGlobal(String uid) => 'inbox_opened_$uid';
  static String _kScoped(String uid, String productId) =>
      'inbox_opened_${uid}_$productId';

  static Future<Map<String, int>> _loadMap(String key) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveMap(String key, Map<String, int> map) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(key, jsonEncode(map));
  }

  /// 讀：全域 opened map
  static Future<Map<String, int>> loadOpenedGlobal(String uid) async {
    return _loadMap(_kGlobal(uid));
  }

  /// 讀：商品 scoped opened map
  static Future<Map<String, int>> loadOpenedForProduct(
      String uid, String productId) async {
    if (productId.isEmpty) return {};
    return _loadMap(_kScoped(uid, productId));
  }

  /// 寫：標記 opened（同時寫入全域 + scoped）
  static Future<void> markOpened(
    String uid, {
    required String productId,
    required String contentItemId,
  }) async {
    if (uid.isEmpty || contentItemId.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    // 1) global
    final kg = _kGlobal(uid);
    final g = await _loadMap(kg);
    g[contentItemId] = now;
    await _saveMap(kg, g);

    // 2) scoped
    if (productId.isNotEmpty) {
      final ks = _kScoped(uid, productId);
      final s = await _loadMap(ks);
      s[contentItemId] = now;
      await _saveMap(ks, s);
    }
  }

  static Future<bool> isOpenedGlobal(String uid, String contentItemId) async {
    final g = await loadOpenedGlobal(uid);
    return g.containsKey(contentItemId);
  }

  static Future<bool> isOpenedForProduct(
      String uid, String productId, String contentItemId) async {
    final s = await loadOpenedForProduct(uid, productId);
    return s.containsKey(contentItemId);
  }

  static Future<void> clearAll(String uid) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kGlobal(uid));
    // scoped keys 不好枚舉；如果你需要「清除全部(含所有商品)」，
    // 我可以幫你加一個 key registry 來追蹤所有 productId。
  }

  static Future<void> clearForProduct(String uid, String productId) async {
    if (productId.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kScoped(uid, productId));
  }

  // ========== 新增：InboxItem 管理 ==========

  static String _kScheduled(String uid) => 'inbox_scheduled_$uid';
  static String _kMissed(String uid) => 'inbox_missed_$uid';

  /// 載入所有收件匣項目（scheduled + missed + opened）
  static Future<List<InboxItem>> load(String uid) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final opened = await loadOpenedGlobal(uid);

    // 1) 載入 scheduled
    final scheduled = await _loadItems(_kScheduled(uid));
    
    // 2) 載入 missed
    final missed = await _loadItems(_kMissed(uid));

    // 3) 合併並判斷狀態
    final all = <String, InboxItem>{};
    
    // 先加入 scheduled
    for (final item in scheduled) {
      final key = '${item.productId}::${item.contentItemId}';
      if (opened.containsKey(item.contentItemId)) {
        // 已開啟
        all[key] = InboxItem(
          productId: item.productId,
          contentItemId: item.contentItemId,
          whenMs: item.whenMs,
          title: item.title,
          body: item.body,
          status: InboxStatus.opened,
        );
      } else if (item.whenMs < now) {
        // 已過期但未開啟 → missed
        all[key] = InboxItem(
          productId: item.productId,
          contentItemId: item.contentItemId,
          whenMs: item.whenMs,
          title: item.title,
          body: item.body,
          status: InboxStatus.missed,
        );
      } else {
        // 未來 → scheduled
        all[key] = item;
      }
    }

    // 再加入 missed（避免覆蓋已開啟的）
    for (final item in missed) {
      final key = '${item.productId}::${item.contentItemId}';
      if (!opened.containsKey(item.contentItemId)) {
        all[key] = InboxItem(
          productId: item.productId,
          contentItemId: item.contentItemId,
          whenMs: item.whenMs,
          title: item.title,
          body: item.body,
          status: InboxStatus.missed,
        );
      }
    }

    return all.values.toList();
  }

  static Future<List<InboxItem>> _loadItems(String key) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((m) => InboxItem.fromJson(
              m.map((k, v) => MapEntry(k.toString(), v))))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveItems(String key, List<InboxItem> items) async {
    final sp = await SharedPreferences.getInstance();
    final list = items.map((item) => item.toJson()).toList();
    await sp.setString(key, jsonEncode(list));
  }

  /// 更新或插入排程項目
  static Future<void> upsertScheduled({
    required String uid,
    required String productId,
    required String contentItemId,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    if (uid.isEmpty || productId.isEmpty || contentItemId.isEmpty) return;

    final key = _kScheduled(uid);
    final items = await _loadItems(key);
    
    // 移除舊的（如果存在）
    items.removeWhere((item) =>
        item.productId == productId && item.contentItemId == contentItemId);

    // 加入新的
    items.add(InboxItem(
      productId: productId,
      contentItemId: contentItemId,
      whenMs: when.millisecondsSinceEpoch,
      title: title,
      body: body,
      status: InboxStatus.scheduled,
    ));

    await _saveItems(key, items);
  }

  /// 掃描並將過期的 scheduled 標記為 missed
  static Future<void> sweepMissed(String uid) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final opened = await loadOpenedGlobal(uid);

    final scheduledKey = _kScheduled(uid);
    final missedKey = _kMissed(uid);

    final scheduled = await _loadItems(scheduledKey);
    final missed = await _loadItems(missedKey);

    final missedSet = <String>{}; // 用於去重
    for (final item in missed) {
      missedSet.add('${item.productId}::${item.contentItemId}');
    }

    final newScheduled = <InboxItem>[];
    final newMissed = <InboxItem>[];

    // 處理 scheduled 項目
    for (final item in scheduled) {
      final key = '${item.productId}::${item.contentItemId}';
      
      if (opened.containsKey(item.contentItemId)) {
        // 已開啟，不加入任何列表
        continue;
      } else if (item.whenMs < now) {
        // 已過期 → 加入 missed
        if (!missedSet.contains(key)) {
          newMissed.add(InboxItem(
            productId: item.productId,
            contentItemId: item.contentItemId,
            whenMs: item.whenMs,
            title: item.title,
            body: item.body,
            status: InboxStatus.missed,
          ));
          missedSet.add(key);
        }
      } else {
        // 未來 → 保留在 scheduled
        newScheduled.add(item);
      }
    }

    // 保留現有的 missed（如果還沒被開啟）
    for (final item in missed) {
      if (!opened.containsKey(item.contentItemId)) {
        final key = '${item.productId}::${item.contentItemId}';
        if (!missedSet.contains(key)) {
          newMissed.add(item);
          missedSet.add(key);
        }
      }
    }

    await _saveItems(scheduledKey, newScheduled);
    await _saveItems(missedKey, newMissed);
  }

  /// 清除所有錯過的項目
  static Future<void> clearMissed(String uid) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kMissed(uid));
  }
}
