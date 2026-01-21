import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PushSkipStore {
  static const _prefix = 'push_skip_v1';

  String _key(String productId) => '$_prefix:$productId';

  Future<Set<String>> getSkippedIds(String productId) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key(productId));
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final list = (jsonDecode(raw) as List).map((e) => e.toString()).toSet();
      return list;
    } catch (_) {
      return <String>{};
    }
  }

  /// 跳過一次：把 contentItemId 加入 skip set
  Future<void> skipOnce({
    required String productId,
    required String contentItemId,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final set = await getSkippedIds(productId);
    set.add(contentItemId);
    await sp.setString(_key(productId), jsonEncode(set.toList()));
  }

  /// 重排時用：把已消耗的 skip 移除（確保只跳過一次）
  Future<void> consume({
    required String productId,
    required Iterable<String> consumedIds,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final set = await getSkippedIds(productId);
    bool changed = false;
    for (final id in consumedIds) {
      changed = set.remove(id) || changed;
    }
    if (!changed) return;
    if (set.isEmpty) {
      await sp.remove(_key(productId));
    } else {
      await sp.setString(_key(productId), jsonEncode(set.toList()));
    }
  }
}
