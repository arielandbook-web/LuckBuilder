import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BubbleCollection {
  final String id;
  final String name;
  final List<String> productIds;

  /// 推播模板（先本機存）
  final int? presetFreqPerDay; // e.g. 1,2,3
  final String? presetTimeMode; // e.g. "fixed", "smart", ... (對齊 timeMode.name)

  final int createdAtMs;
  final int updatedAtMs;

  const BubbleCollection({
    required this.id,
    required this.name,
    required this.productIds,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.presetFreqPerDay,
    this.presetTimeMode,
  });

  BubbleCollection copyWith({
    String? name,
    List<String>? productIds,
    int? presetFreqPerDay,
    String? presetTimeMode,
    int? updatedAtMs,
  }) {
    return BubbleCollection(
      id: id,
      name: name ?? this.name,
      productIds: productIds ?? this.productIds,
      presetFreqPerDay: presetFreqPerDay ?? this.presetFreqPerDay,
      presetTimeMode: presetTimeMode ?? this.presetTimeMode,
      createdAtMs: createdAtMs,
      updatedAtMs: updatedAtMs ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'productIds': productIds,
        'presetFreqPerDay': presetFreqPerDay,
        'presetTimeMode': presetTimeMode,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
      };

  static BubbleCollection fromJson(Map<String, dynamic> j) {
    return BubbleCollection(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      productIds: (j['productIds'] is List)
          ? (j['productIds'] as List).map((e) => e.toString()).toList()
          : <String>[],
      presetFreqPerDay: (j['presetFreqPerDay'] as num?)?.toInt(),
      presetTimeMode: j['presetTimeMode']?.toString(),
      createdAtMs: (j['createdAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      updatedAtMs: (j['updatedAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class CollectionsStore {
  static const _prefix = 'bubble_collections_v1_';
  static String _key(String uid) => '$_prefix$uid';

  static Future<List<BubbleCollection>> load(String uid) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key(uid));
    if (raw == null || raw.isEmpty) return [];
    try {
      final arr = jsonDecode(raw) as List<dynamic>;
      final list = arr
          .whereType<Map>()
          .map((m) => BubbleCollection.fromJson(m.cast<String, dynamic>()))
          .toList();
      list.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(String uid, List<BubbleCollection> list) async {
    final sp = await SharedPreferences.getInstance();
    final arr = list.map((e) => e.toJson()).toList();
    await sp.setString(_key(uid), jsonEncode(arr));
  }
}
