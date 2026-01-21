import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../collections/daily_routine_provider.dart';
import '../providers/providers.dart';
import '../notifications/push_orchestrator.dart';
import '../../notifications/daily_routine_store.dart';
import '../../notifications/push_timeline_provider.dart';
import 'daily_routine_order_page.dart';
import 'widgets/bubble_card.dart';

/// ✅ 播放清單式收藏集內頁（本機排序、不動後端）
/// - ReorderableListView 拖曳排序
/// - 批次：全部開推播 / 全部關推播 / 移除未購買
/// - 預覽未來 3 天：用 upcomingTimelineProvider 真資料（只篩本收藏集的商品）
///
/// 注意：排序目前是「本機 session 記憶」；之後要持久化可接 SharedPreferences/Firestore（但你說先不動後端）
final _collectionOrderProvider =
    StateNotifierProvider.family<_OrderController, List<String>, String>(
  (ref, collectionId) => _OrderController(),
);

class _OrderController extends StateNotifier<List<String>> {
  _OrderController() : super(const []);

  String? _key;

  Future<void> load({
    required String collectionId,
    required List<String> fallbackIds,
  }) async {
    _key = 'lb_col_order_$collectionId';
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key!) ?? const <String>[];

    // ✅ 合併：保留 saved 的順序 + 把新出現的 pid append 到最後
    final fb = fallbackIds.map((e) => e.toString()).toList();
    final setFb = fb.toSet();

    final merged = <String>[];
    for (final pid in saved) {
      final p = pid.toString();
      if (setFb.contains(p)) merged.add(p);
    }
    for (final pid in fb) {
      if (!merged.contains(pid)) merged.add(pid);
    }

    state = merged;
    await _save();
  }

  Future<void> _save() async {
    if (_key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key!, state);
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = List<String>.from(state);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
    await _save();
  }

  Future<void> removeWhere(bool Function(String pid) test) async {
    state = state.where((pid) => !test(pid)).toList();
    await _save();
  }

  Future<void> resetToDefault(List<String> fallbackIds) async {
    state = List<String>.from(fallbackIds);
    await _save();
  }
}

class CollectionDetailPage extends ConsumerStatefulWidget {
  final String collectionId;
  final String collectionName;
  final List<String> productIds;

  const CollectionDetailPage({
    super.key,
    required this.collectionId,
    required this.collectionName,
    required this.productIds,
  });

  @override
  ConsumerState<CollectionDetailPage> createState() =>
      _CollectionDetailPageState();

  static Future<void> _batchSetPush({
    required BuildContext context,
    required WidgetRef ref,
    required List<String> pids,
    required Set<String> purchasedSet,
    required bool enable,
  }) async {
    final targets = pids.where(purchasedSet.contains).toList();
    if (targets.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('沒有已購買商品可操作')),
        );
      }
      return;
    }
    final uid = ref.read(uidProvider);
    final repo = ref.read(libraryRepoProvider);
    for (final pid in targets) {
      await repo.setPushEnabled(uid, pid, enable);
    }
    await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(enable ? '已對收藏集內已購買商品全部開推播' : '已對收藏集內已購買商品全部關推播')),
      );
    }
  }

  static Future<void> _showTimelinePreviewSheet({
    required BuildContext context,
    required WidgetRef ref,
    required AsyncValue<List<dynamic>> timelineAsync,
    required AsyncValue<dynamic> productsMapAsync,
    required Set<String> filterProductIds,
  }) async {
    final list =
        timelineAsync.maybeWhen(data: (v) => v, orElse: () => <dynamic>[]);
    if (list.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('目前沒有已排程的 timeline（可先到推播中心重排）')),
        );
      }
      return;
    }
    Map<String, dynamic> pm = {};
    productsMapAsync.when(
      data: (m) {
        pm = (m as Map).map((k, v) => MapEntry(k.toString(), v as dynamic));
      },
      loading: () {},
      error: (_, __) {},
    );
    final now = DateTime.now();
    final filtered = <dynamic>[];
    for (final t in list) {
      try {
        final pid = (t as dynamic).productId?.toString();
        final when = (t as dynamic).when as DateTime?;
        if (pid == null || when == null) continue;
        if (!filterProductIds.contains(pid)) continue;
        if (when.isBefore(now.subtract(const Duration(hours: 1)))) continue;
        filtered.add(t);
      } catch (_) {}
    }
    filtered.sort((a, b) {
      final wa = (a as dynamic).when as DateTime;
      final wb = (b as dynamic).when as DateTime;
      return wa.compareTo(wb);
    });
    if (filtered.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('本收藏集在未來 3 天沒有排到推播')),
        );
      }
      return;
    }
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('未來推播預覽（本收藏集）',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () async {
                        await PushOrchestrator.rescheduleNextDays(
                            ref: ref, days: 3);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('重排 3 天'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length.clamp(0, 30),
                    separatorBuilder: (_, __) =>
                        Divider(color: Colors.white.withValues(alpha: 0.08)),
                    itemBuilder: (_, i) {
                      final t = filtered[i];
                      final when = (t as dynamic).when as DateTime;
                      final pid = (t as dynamic).productId?.toString() ?? '';
                      final title = (pm[pid] != null)
                          ? (pm[pid] as dynamic).title.toString()
                          : pid;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                          '${_ymd(when)} ${_hm(when)}',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.70)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CollectionDetailPageState extends ConsumerState<CollectionDetailPage> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    await ref.read(_collectionOrderProvider(widget.collectionId).notifier).load(
          collectionId: widget.collectionId,
          fallbackIds: widget.productIds,
        );
    if (!mounted) return;
    setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(_collectionOrderProvider(widget.collectionId));
    final productsMapAsync = ref.watch(productsMapProvider);
    final libAsync = ref.watch(libraryProductsProvider);
    final timelineAsync = ref.watch(upcomingTimelineProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.collectionName),
        actions: [
          IconButton(
            tooltip: '預覽未來 3 天',
            icon: const Icon(Icons.timeline),
            onPressed: () async {
              await CollectionDetailPage._showTimelinePreviewSheet(
                context: context,
                ref: ref,
                timelineAsync: timelineAsync,
                productsMapAsync: productsMapAsync,
                filterProductIds: order.toSet(),
              );
            },
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : productsMapAsync.when(
              data: (productsMap) {
                return libAsync.when(
                  data: (lib) {
                    // ✅ 已購買/推播中 set（只用於顯示與批次操作）
                    final purchasedSet = <String>{};
                    final pushingSet = <String>{};
                    for (final lp in lib) {
                      purchasedSet.add(lp.productId);
                      if (lp.pushEnabled) pushingSet.add(lp.productId);
                    }

                    // ✅ order 中可能有不存在的商品：安全過濾
                    final safeOrder = order
                        .where((pid) => productsMap.containsKey(pid))
                        .toList();

                    return Column(
                      children: [
                        const SizedBox(height: 10),

                        // 顶部資訊卡（播放清單感）
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: BubbleCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('播放清單',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color:
                                          Colors.white.withValues(alpha: 0.95),
                                    )),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _miniChip('總數', '${safeOrder.length}'),
                                    _miniChip('已購買',
                                        '${safeOrder.where(purchasedSet.contains).length}'),
                                    _miniChip('推播中',
                                        '${safeOrder.where(pushingSet.contains).length}'),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text('拖曳排序決定「日常優先順序」的基礎（本機，不動後端）',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.70),
                                      fontSize: 12,
                                    )),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.auto_awesome),
                                        label: const Text('設為日常優先順序'),
                                        onPressed: () async {
                                          final ok =
                                              await _confirmMakeDaily(context);
                                          if (!ok) return;
                                          if (!context.mounted) return;
                                          await _applyAsDailyRoutine(
                                            context: context,
                                            ref: ref,
                                            collectionId: widget.collectionId,
                                            orderedProductIds: order,
                                            purchasedSet: purchasedSet,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // 批次操作列
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(
                                      Icons.notifications_active_outlined),
                                  label: const Text('全部開推播'),
                                  onPressed: () async {
                                    await CollectionDetailPage._batchSetPush(
                                      context: context,
                                      ref: ref,
                                      pids: safeOrder,
                                      purchasedSet: purchasedSet,
                                      enable: true,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(
                                      Icons.notifications_off_outlined),
                                  label: const Text('全部關推播'),
                                  onPressed: () async {
                                    await CollectionDetailPage._batchSetPush(
                                      context: context,
                                      ref: ref,
                                      pids: safeOrder,
                                      purchasedSet: purchasedSet,
                                      enable: false,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(
                                      Icons.cleaning_services_outlined),
                                  label: const Text('移除未購買'),
                                  onPressed: () async {
                                    await ref
                                        .read(_collectionOrderProvider(
                                                widget.collectionId)
                                            .notifier)
                                        .removeWhere(
                                          (pid) => !purchasedSet.contains(pid),
                                        );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text('已從收藏集清單移除未購買項目（本機永久保存）')),
                                      );
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.restart_alt),
                                  label: const Text('重置順序'),
                                  onPressed: () async {
                                    final ok = await _confirmReset(context);
                                    if (!ok) return;
                                    await ref
                                        .read(_collectionOrderProvider(
                                                widget.collectionId)
                                            .notifier)
                                        .resetToDefault(widget.productIds);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text('已重置為預設順序（本機永久保存）')),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // 播放清單（拖曳排序）
                        Expanded(
                          child: ReorderableListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            itemCount: safeOrder.length,
                            onReorder: (oldIndex, newIndex) async {
                              await ref
                                  .read(_collectionOrderProvider(
                                          widget.collectionId)
                                      .notifier)
                                  .reorder(oldIndex, newIndex);
                            },
                            itemBuilder: (context, i) {
                              final pid = safeOrder[i];
                              final p = productsMap[pid]!;
                              final isPurchased = purchasedSet.contains(pid);
                              final isPushing = pushingSet.contains(pid);

                              return Padding(
                                key:
                                    ValueKey('col-${widget.collectionId}-$pid'),
                                padding: const EdgeInsets.only(bottom: 10),
                                child: BubbleCard(
                                  onTap: () {
                                    // 你若想點擊進商品詳情，這裡改成 ProductPage(productId: pid)
                                    // 目前先不跳，避免你路由不同造成整合風險
                                  },
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Drag handle 視覺提示
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Icon(Icons.drag_handle,
                                            color: Colors.white
                                                .withValues(alpha: 0.75)),
                                      ),
                                      const SizedBox(width: 10),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    p.title,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isPurchased) _badge('已購買'),
                                                if (!isPurchased)
                                                  _badge('未購買', dim: true),
                                                if (isPushing) _badge('推播中'),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '${p.topicId.isEmpty ? '—' : p.topicId} · ${p.level}',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.72),
                                                fontSize: 12,
                                              ),
                                            ),
                                            if ((p.levelGoal ?? '').trim().isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                p.levelGoal!,
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.72),
                                                  fontSize: 12,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 10),

                                      // 單筆推播切換（只對已購買有效）
                                      IconButton(
                                        tooltip: isPushing ? '關閉推播' : '開啟推播',
                                        icon: Icon(
                                          isPushing
                                              ? Icons.notifications_active
                                              : Icons.notifications_none,
                                          color: isPurchased
                                              ? Colors.white
                                                  .withValues(alpha: 0.95)
                                              : Colors.white
                                                  .withValues(alpha: 0.30),
                                        ),
                                        onPressed: !isPurchased
                                            ? null
                                            : () async {
                                                await ref
                                                    .read(libraryRepoProvider)
                                                    .setPushEnabled(
                                                      ref.read(uidProvider),
                                                      pid,
                                                      !isPushing,
                                                    );
                                                await PushOrchestrator
                                                    .rescheduleNextDays(
                                                        ref: ref, days: 3);
                                              },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('library error: $e')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('products error: $e')),
            ),
    );
  }
}

Widget _miniChip(String k, String v) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        '$k $v',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.90),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

Widget _badge(String text, {bool dim = false}) => Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: dim ? 0.06 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: Colors.white.withValues(alpha: dim ? 0.08 : 0.12)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Colors.white.withValues(alpha: dim ? 0.55 : 0.95),
        ),
      ),
    );

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<bool> _confirmReset(BuildContext context) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('重置為預設順序？'),
      content: const Text('這會把你拖曳調整的順序恢復成收藏集原本的順序（會永久保存到本機）。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('重置'),
        ),
      ],
    ),
  );
  return res ?? false;
}

Future<bool> _confirmMakeDaily(BuildContext context) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('設為日常優先順序？'),
      content: const Text('會把此收藏集目前排序套用為「日常」的優先順序，並重排未來 3 天推播。'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消')),
        ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('套用')),
      ],
    ),
  );
  return res ?? false;
}

Future<void> _applyAsDailyRoutine({
  required BuildContext context,
  required WidgetRef ref,
  required String collectionId,
  required List<String> orderedProductIds,
  required Set<String> purchasedSet, // ✅ 只納入已購買
}) async {
  try {
    final uid = ref.read(uidProvider);

    // ✅ 只取已購買，維持你拖曳的順序
    final ids = orderedProductIds.where(purchasedSet.contains).toList();

    if (ids.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('此收藏集沒有已購買商品可設為日常')),
        );
      }
      return;
    }

    final next = DailyRoutine(
      activeCollectionId: collectionId,
      orderedProductIds: ids,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    await DailyRoutineStore.save(uid, next);

    await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
    ref.invalidate(upcomingTimelineProvider);
    ref.invalidate(dailyRoutineProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已套用為日常優先順序，並重排未來 3 天推播')),
      );

      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DailyRoutineOrderPage()),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('套用日常失敗：$e')),
      );
    }
  }
}
