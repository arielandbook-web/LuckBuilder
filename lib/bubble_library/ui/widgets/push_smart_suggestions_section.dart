import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_library.dart';
import '../../models/push_config.dart';
import '../../providers/providers.dart';
import '../../notifications/push_orchestrator.dart';
import '../../../notifications/suggestion_dismiss_store.dart';
import '../../../notifications/push_timeline_provider.dart';

class PushSmartSuggestionsSection extends ConsumerStatefulWidget {
  const PushSmartSuggestionsSection({super.key});

  @override
  ConsumerState<PushSmartSuggestionsSection> createState() =>
      _PushSmartSuggestionsSectionState();
}

class _PushSmartSuggestionsSectionState
    extends ConsumerState<PushSmartSuggestionsSection> {
  bool _busy = false;

  Future<void> _applyAndReschedule(Future<void> Function() op) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await op();
      await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
      ref.invalidate(upcomingTimelineProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已套用建議並重排未來 3 天推播')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String uid;
    try {
      uid = ref.read(uidProvider);
    } catch (_) {
      return const SizedBox.shrink();
    }

    final globalAsync = ref.watch(globalPushSettingsProvider);
    final libAsync = ref.watch(libraryProductsProvider);
    final savedAsync = ref.watch(savedItemsProvider);

    return globalAsync.when(
      data: (g) => libAsync.when(
        data: (lib) => savedAsync.when(
          data: (savedMap) {
            final pushing = lib.where((e) => !e.isHidden && e.pushEnabled).toList();
            if (pushing.isEmpty) return const SizedBox.shrink();

            // 1) 建議：cap 太低 + 推播中商品太多
            final pushingCount = pushing.length;
            final cap = g.dailyTotalCap;
            final bool shouldSuggestCap = pushingCount >= 3 && cap <= 8;

            // 2) 建議：你常在某個時段點開 -> 建議改成那個 presetSlots
            final slot = _dominantSlotFromLastOpened(pushing);
            final bool shouldSuggestSlot = slot != null;

            // 3) 建議：你收藏/稍後很多 -> 建議 preferSaved
            final savedInteresting = savedMap.values.where((s) {
              return (s.favorite == true) || (s.reviewLater == true);
            }).length;
            final bool anyNotPreferSaved = pushing.any((lp) {
              return lp.pushConfig.contentMode != PushContentMode.preferSaved;
            });
            final bool shouldSuggestPreferSaved =
                savedInteresting >= 5 && anyNotPreferSaved;

            final suggestions = <_Suggestion>[];

            if (shouldSuggestCap) {
              suggestions.add(_Suggestion(
                id: 'cap_low',
                title: '每日上限可能太低',
                body:
                    '你目前推播中 $pushingCount 個商品，但每日總上限只有 $cap，可能會漏掉內容。',
                primaryText: '調到 12',
                secondaryText: '調到 20',
                onPrimary: () => _applyAndReschedule(() async {
                  final repo = ref.read(pushSettingsRepoProvider);
                  await repo.setGlobal(uid, g.copyWith(dailyTotalCap: 12));
                }),
                onSecondary: () => _applyAndReschedule(() async {
                  final repo = ref.read(pushSettingsRepoProvider);
                  await repo.setGlobal(uid, g.copyWith(dailyTotalCap: 20));
                }),
              ));
            }

            if (shouldSuggestSlot) {
              final slotLabel = _slotLabel(slot);
              suggestions.add(_Suggestion(
                id: 'slot_$slot',
                title: '推播時段更貼近你的習慣',
                body: '你最近比較常在「$slotLabel」打開學習，建議把推播時段改成同一個時段。',
                primaryText: '一鍵改成 $slotLabel',
                secondaryText: '先不要',
                onPrimary: () => _applyAndReschedule(() async {
                  final repo = ref.read(libraryRepoProvider);

                  for (final lp in pushing) {
                    final m = Map<String, dynamic>.from(lp.pushConfig.toMap());
                    m['timeMode'] = PushTimeMode.preset.name; // 'preset'
                    m['presetSlots'] = [slot];
                    m['customTimes'] = [];
                    await repo.setPushConfig(uid, lp.productId, m);
                  }
                }),
                onSecondary: () async {
                  await SuggestionDismissStore.dismiss(uid, 'slot_$slot', days: 3);
                  if (mounted) setState(() {});
                },
              ));
            }

            if (shouldSuggestPreferSaved) {
              suggestions.add(_Suggestion(
                id: 'prefer_saved',
                title: '讓推播優先推你收藏/稍後',
                body: '你目前有 $savedInteresting 張卡片標記「收藏/稍後」，把推播模式切成「優先收藏」會更有感。',
                primaryText: '一鍵套用',
                secondaryText: '先不要',
                onPrimary: () => _applyAndReschedule(() async {
                  final repo = ref.read(libraryRepoProvider);
                  for (final lp in pushing) {
                    final m = Map<String, dynamic>.from(lp.pushConfig.toMap());
                    m['contentMode'] = PushContentMode.preferSaved.name; // 'preferSaved'
                    await repo.setPushConfig(uid, lp.productId, m);
                  }
                }),
                onSecondary: () async {
                  await SuggestionDismissStore.dismiss(uid, 'prefer_saved', days: 3);
                  if (mounted) setState(() {});
                },
              ));
            }

            if (suggestions.isEmpty) return const SizedBox.shrink();

            return FutureBuilder<List<_Suggestion>>(
              future: _filterDismissed(uid, suggestions),
              builder: (context, snap) {
                final list = snap.data ?? const <_Suggestion>[];
                if (list.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '智慧建議',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const Spacer(),
                        if (_busy)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...list.take(3).map(_SuggestionCard.new),
                  ],
                );
              },
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<List<_Suggestion>> _filterDismissed(
      String uid, List<_Suggestion> list) async {
    final out = <_Suggestion>[];
    for (final s in list) {
      final dismissed = await SuggestionDismissStore.isDismissed(uid, s.id);
      if (!dismissed) out.add(s);
    }
    return out;
  }

  String? _dominantSlotFromLastOpened(List<UserLibraryProduct> pushing) {
    // 用 pushing 中所有 lastOpenedAt 做簡單分桶（MVP）
    final counts = <String, int>{
      'morning': 0,
      'noon': 0,
      'evening': 0,
      'night': 0,
    };

    int total = 0;
    for (final lp in pushing) {
      final dt = lp.lastOpenedAt;
      if (dt == null) continue;
      total += 1;
      final h = dt.hour;
      if (h >= 5 && h < 11) counts['morning'] = counts['morning']! + 1;
      else if (h >= 11 && h < 17) counts['noon'] = counts['noon']! + 1;
      else if (h >= 17 && h < 21) counts['evening'] = counts['evening']! + 1;
      else counts['night'] = counts['night']! + 1;
    }

    if (total == 0) return null;

    // 需要「明顯偏好」才建議：最高桶占比 >= 60%
    String best = 'night';
    int bestV = -1;
    counts.forEach((k, v) {
      if (v > bestV) {
        bestV = v;
        best = k;
      }
    });

    if (bestV / total < 0.6) return null;
    return best;
  }

  String _slotLabel(String slot) {
    switch (slot) {
      case 'morning':
        return '早上';
      case 'noon':
        return '中午';
      case 'evening':
        return '傍晚';
      case 'night':
      default:
        return '睡前';
    }
  }
}

class _Suggestion {
  final String id;
  final String title;
  final String body;
  final String primaryText;
  final String secondaryText;
  final Future<void> Function() onPrimary;
  final Future<void> Function() onSecondary;

  _Suggestion({
    required this.id,
    required this.title,
    required this.body,
    required this.primaryText,
    required this.secondaryText,
    required this.onPrimary,
    required this.onSecondary,
  });
}

class _SuggestionCard extends StatelessWidget {
  final _Suggestion s;
  const _SuggestionCard(this.s);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(s.body),
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => s.onPrimary(),
                  child: Text(s.primaryText),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => s.onSecondary(),
                  child: Text(s.secondaryText),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
