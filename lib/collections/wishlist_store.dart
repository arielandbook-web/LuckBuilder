import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalWishlistItem {
  final String productId;
  final int addedAtMs;
  final bool isFavorite;

  const LocalWishlistItem({
    required this.productId,
    required this.addedAtMs,
    required this.isFavorite,
  });

  LocalWishlistItem copyWith({int? addedAtMs, bool? isFavorite}) {
    return LocalWishlistItem(
      productId: productId,
      addedAtMs: addedAtMs ?? this.addedAtMs,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'addedAtMs': addedAtMs,
        'isFavorite': isFavorite,
      };

  static LocalWishlistItem fromAny(dynamic raw) {
    // ✅ 舊格式：直接是字串 productId
    if (raw is String) {
      return LocalWishlistItem(
        productId: raw,
        addedAtMs: DateTime.now().millisecondsSinceEpoch,
        isFavorite: false,
      );
    }

    // ✅ 新格式：map
    if (raw is Map) {
      final pid = (raw['productId'] ?? '').toString();
      final added = (raw['addedAtMs'] is int)
          ? raw['addedAtMs'] as int
          : int.tryParse((raw['addedAtMs'] ?? '').toString()) ??
              DateTime.now().millisecondsSinceEpoch;
      final fav = (raw['isFavorite'] is bool)
          ? raw['isFavorite'] as bool
          : ((raw['isFavorite'] ?? '').toString().toLowerCase() == 'true');

      return LocalWishlistItem(productId: pid, addedAtMs: added, isFavorite: fav);
    }

    // fallback
    return LocalWishlistItem(
      productId: raw.toString(),
      addedAtMs: DateTime.now().millisecondsSinceEpoch,
      isFavorite: false,
    );
  }
}

class WishlistStore {
  static String _key(String uid) => 'wishlist_v2_$uid';

  static Future<List<LocalWishlistItem>> load(String uid) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key(uid));
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);

      if (decoded is List) {
        final list = decoded.map(LocalWishlistItem.fromAny).toList();

        // 去重（保留較新的 addedAt）
        final map = <String, LocalWishlistItem>{};
        for (final it in list) {
          final prev = map[it.productId];
          if (prev == null) {
            map[it.productId] = it;
          } else {
            map[it.productId] =
                (it.addedAtMs > prev.addedAtMs) ? it : prev;
          }
        }
        return map.values.toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(String uid, List<LocalWishlistItem> items) async {
    final sp = await SharedPreferences.getInstance();

    // 去重
    final map = <String, LocalWishlistItem>{};
    for (final it in items) {
      map[it.productId] = it;
    }

    final out = map.values
        .map((e) => e.toMap())
        .toList()
      ..sort((a, b) => (b['addedAtMs'] as int).compareTo(a['addedAtMs'] as int));

    await sp.setString(_key(uid), jsonEncode(out.take(800).toList()));
  }

  static Future<bool> toggleCollect(String uid, String productId) async {
    final list = await load(uid);
    final idx = list.indexWhere((e) => e.productId == productId);

    if (idx >= 0) {
      list.removeAt(idx);
      await save(uid, list);
      return false;
    } else {
      list.insert(
        0,
        LocalWishlistItem(
          productId: productId,
          addedAtMs: DateTime.now().millisecondsSinceEpoch,
          isFavorite: false,
        ),
      );
      await save(uid, list);
      return true;
    }
  }

  static Future<void> remove(String uid, String productId) async {
    final list = await load(uid);
    list.removeWhere((e) => e.productId == productId);
    await save(uid, list);
  }

  static Future<void> toggleFavorite(String uid, String productId) async {
    final list = await load(uid);
    final idx = list.indexWhere((e) => e.productId == productId);
    if (idx < 0) return;

    final cur = list[idx];
    list[idx] = cur.copyWith(isFavorite: !cur.isFavorite);
    await save(uid, list);
  }
}
