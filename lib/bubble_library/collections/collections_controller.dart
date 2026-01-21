import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import 'collections_store.dart';

final collectionsControllerProvider = StateNotifierProvider.autoDispose<
    CollectionsController, AsyncValue<List<BubbleCollection>>>((ref) {
  return CollectionsController(ref);
});

class CollectionsController
    extends StateNotifier<AsyncValue<List<BubbleCollection>>> {
  final Ref ref;
  CollectionsController(this.ref) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = ref.read(uidProvider);
      final list = await CollectionsStore.load(uid);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> reload() => _load();

  String _newId() {
    final r = Random();
    return 'c_${DateTime.now().millisecondsSinceEpoch}_${r.nextInt(9999)}';
  }

  Future<void> create(String name) async {
    final uid = ref.read(uidProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final cur = state.value ?? [];
    final next = [
      BubbleCollection(
        id: _newId(),
        name: name.trim().isEmpty ? '未命名收藏集' : name.trim(),
        productIds: const [],
        createdAtMs: now,
        updatedAtMs: now,
      ),
      ...cur,
    ];
    state = AsyncValue.data(next);
    await CollectionsStore.save(uid, next);
  }

  Future<void> rename(String collectionId, String name) async {
    final uid = ref.read(uidProvider);
    final cur = state.value ?? [];
    final next = cur
        .map((c) => c.id == collectionId ? c.copyWith(name: name.trim()) : c)
        .toList();
    state = AsyncValue.data(next);
    await CollectionsStore.save(uid, next);
  }

  Future<void> remove(String collectionId) async {
    final uid = ref.read(uidProvider);
    final cur = state.value ?? [];
    final next = cur.where((c) => c.id != collectionId).toList();
    state = AsyncValue.data(next);
    await CollectionsStore.save(uid, next);
  }

  Future<void> toggleProduct({
    required String collectionId,
    required String productId,
  }) async {
    final uid = ref.read(uidProvider);
    final cur = state.value ?? [];
    final next = cur.map((c) {
      if (c.id != collectionId) return c;
      final set = c.productIds.toSet();
      if (set.contains(productId)) {
        set.remove(productId);
      } else {
        set.add(productId);
      }
      return c.copyWith(productIds: set.toList());
    }).toList();

    state = AsyncValue.data(next);
    await CollectionsStore.save(uid, next);
  }

  Future<void> setPreset({
    required String collectionId,
    required int? freqPerDay,
    required String? timeModeName,
  }) async {
    final uid = ref.read(uidProvider);
    final cur = state.value ?? [];
    final next = cur.map((c) {
      if (c.id != collectionId) return c;
      return c.copyWith(
          presetFreqPerDay: freqPerDay, presetTimeMode: timeModeName);
    }).toList();

    state = AsyncValue.data(next);
    await CollectionsStore.save(uid, next);
  }
}
