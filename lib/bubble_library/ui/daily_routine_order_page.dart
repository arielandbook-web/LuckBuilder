import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collections/collections_store.dart';
import '../collections/daily_routine_provider.dart';
import '../notifications/push_orchestrator.dart';
import '../providers/providers.dart';
import '../../notifications/daily_routine_store.dart';
import '../../notifications/push_timeline_provider.dart';

class DailyRoutineOrderPage extends ConsumerStatefulWidget {
  const DailyRoutineOrderPage({super.key});

  @override
  ConsumerState<DailyRoutineOrderPage> createState() =>
      _DailyRoutineOrderPageState();
}

class _DailyRoutineOrderPageState extends ConsumerState<DailyRoutineOrderPage> {
  bool _loaded = false;
  DailyRoutine _routine = DailyRoutine.empty();
  List<String> _ids = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _init();
  }

  Future<void> _init() async {
    final uid = ref.read(uidProvider);
    final r = await DailyRoutineStore.load(uid);
    setState(() {
      _routine = r;
      _ids = List<String>.from(r.orderedProductIds);
    });
  }

  Future<void> _restoreFromCollectionOrder() async {
    final uid = ref.read(uidProvider);
    final activeCid = _routine.activeCollectionId;

    if (activeCid == null || activeCid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('目前沒有啟用日常收藏集')),
        );
      }
      return;
    }

    final cols = await CollectionsStore.load(uid);
    final col = cols.where((c) => c.id == activeCid).firstOrNull;

    if (col == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('找不到對應的收藏集（可能已刪除）')),
        );
      }
      return;
    }

    final curSet = _ids.toSet();

    final restored = <String>[
      ...col.productIds.where(curSet.contains),
      ..._ids.where((id) => !col.productIds.contains(id)),
    ];

    setState(() => _ids = restored);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已恢復為「${col.name}」的原順序（尚未保存）')),
      );
    }
  }

  Future<void> _save() async {
    final uid = ref.read(uidProvider);

    final next = DailyRoutine(
      activeCollectionId: _routine.activeCollectionId,
      orderedProductIds: _ids,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    await DailyRoutineStore.save(uid, next);

    await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
    ref.invalidate(upcomingTimelineProvider);
    ref.invalidate(dailyRoutineProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已更新日常順序，並重排未來 3 天推播')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('日常順序'),
        actions: [
          IconButton(
            tooltip: '恢復收藏集原順序',
            icon: const Icon(Icons.restart_alt),
            onPressed: _ids.isEmpty ? null : _restoreFromCollectionOrder,
          ),
          TextButton(
            onPressed: _ids.isEmpty ? null : _save,
            child:
                const Text('保存', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
      body: productsAsync.when(
        data: (products) {
          if (_routine.activeCollectionId == null ||
              _routine.activeCollectionId!.isEmpty) {
            return const Center(child: Text('尚未啟用日常，請先在收藏集管理設為日常'));
          }
          if (_ids.isEmpty) {
            return const Center(child: Text('日常清單是空的'));
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _ids.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _ids.removeAt(oldIndex);
                _ids.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final pid = _ids[index];
              final title = products[pid]?.title ?? pid;

              return Card(
                key: ValueKey('daily_$pid'),
                child: ListTile(
                  leading: const Icon(Icons.drag_handle),
                  title:
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('順序 ${index + 1}'),
                  trailing: IconButton(
                    tooltip: '移出日常',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() => _ids.removeAt(index));
                    },
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('products error: $e')),
      ),
    );
  }
}

extension _FirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
