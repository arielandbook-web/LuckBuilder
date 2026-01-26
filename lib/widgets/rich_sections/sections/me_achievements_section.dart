import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_tokens.dart';
import '../../app_card.dart';

import '../../../bubble_library/providers/providers.dart';
import '../../../collections/wishlist_provider.dart';
import '../user/me_prefs_store.dart';
import '../user_learning_store.dart';

class MeAchievementsSection extends ConsumerStatefulWidget {
  const MeAchievementsSection({super.key});

  @override
  ConsumerState<MeAchievementsSection> createState() =>
      _MeAchievementsSectionState();
}

class _MeAchievementsSectionState extends ConsumerState<MeAchievementsSection> {
  static const _localKey = 'local';
  int _streak = 0;
  int _learnedDays = 0;
  List<String> _tags = [];
  bool _loading = true;

  final _store = UserLearningStore();

  String _uidOrLocal() {
    try {
      return ref.read(uidProvider);
    } catch (_) {
      return _localKey;
    }
  }

  @override
  void initState() {
    super.initState();
    _reloadLocal();
  }

  Future<void> _reloadLocal() async {
    final key = _uidOrLocal();
    final streak = await _store.globalStreak();
    final weeklyCount = await _store.globalWeeklyCount();
    final tags = await MePrefsStore.getInterestTags(key);
    if (!mounted) return;
    setState(() {
      _streak = streak;
      _learnedDays = weeklyCount; // 使用週完成度作為累積指標
      _tags = tags;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final libAsync = _safeLib();
    final wishAsync = _safeWish();

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('里程碑 / 成就',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: tokens.textPrimary)),
              const Spacer(),
              IconButton(
                tooltip: '重新整理',
                onPressed: _reloadLocal,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            libAsync.when(
              data: (lib) {
                return wishAsync.when(
                  data: (wish) {
                    final purchased = lib.where((e) {
                      try {
                        return (e as dynamic).isHidden != true;
                      } catch (_) {
                        return false;
                      }
                    }).toList();

                    final pushing = purchased.where((e) {
                      try {
                        return (e as dynamic).pushEnabled == true;
                      } catch (_) {
                        return false;
                      }
                    }).length;

                    final favIds = <String>{};
                    for (final lp in purchased) {
                      try {
                        if ((lp as dynamic).isFavorite == true) {
                          favIds.add((lp as dynamic).productId.toString());
                        }
                      } catch (_) {}
                    }
                    for (final w in wish) {
                      try {
                        if ((w as dynamic).isFavorite == true) {
                          favIds.add((w as dynamic).productId.toString());
                        }
                      } catch (_) {}
                    }

                    final streak = _streak;
                    final learnedDays = _learnedDays;

                    final achievements = <_Ach>[
                      _Ach(
                        title: '收藏家',
                        desc: '累積收藏（已購買+願望）',
                        current: purchased.length + wish.length,
                        targets: const [1, 5, 10, 30],
                        icon: Icons.inventory_2_outlined,
                      ),
                      _Ach(
                        title: '推播玩家',
                        desc: '啟用推播的主題數',
                        current: pushing,
                        targets: const [1, 3, 5, 10],
                        icon: Icons.notifications_active_outlined,
                      ),
                      _Ach(
                        title: '最愛清單',
                        desc: '加入最愛的主題數',
                        current: favIds.length,
                        targets: const [1, 3, 5, 10],
                        icon: Icons.star_border,
                      ),
                      _Ach(
                        title: '懂你的人',
                        desc: '設定興趣標籤',
                        current: _tags.length,
                        targets: const [1, 3, 5, 10],
                        icon: Icons.local_offer_outlined,
                      ),
                      _Ach(
                        title: '連續學習',
                        desc: '連續學習天數（本機）',
                        current: streak,
                        targets: const [1, 3, 7, 14, 30],
                        icon: Icons.bolt_outlined,
                      ),
                      _Ach(
                        title: '學習累積',
                        desc: '學習天數總計（本機）',
                        current: learnedDays,
                        targets: const [1, 7, 30, 60, 100],
                        icon: Icons.auto_graph_outlined,
                      ),
                    ];

                    return Column(
                      children:
                          achievements.map((a) => _achRow(context, a)).toList(),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('wishlist error: $e',
                      style: TextStyle(color: tokens.textSecondary)),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('library error: $e',
                  style: TextStyle(color: tokens.textSecondary)),
            ),
          const SizedBox(height: 10),
          Text(
            '提示：連續學習/學習累積 需要在「使用者真的學習」時呼叫 LearnLogStore.markLearnedToday()（我下一步給你最小插入點）',
            style: TextStyle(color: tokens.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  AsyncValue<List<dynamic>> _safeLib() {
    try {
      ref.read(uidProvider);
      return ref.watch(libraryProductsProvider);
    } catch (_) {
      return const AsyncValue.data(<dynamic>[]);
    }
  }

  AsyncValue<List<dynamic>> _safeWish() {
    try {
      ref.read(uidProvider);
      return ref.watch(localWishlistProvider);
    } catch (_) {
      return const AsyncValue.data(<dynamic>[]);
    }
  }

  Widget _achRow(BuildContext context, _Ach a) {
    final tokens = context.tokens;

    final nextTarget = a.nextTarget();
    final done = nextTarget == null;
    final target = nextTarget ?? a.targets.last;
    final p = (a.current.clamp(0, target)) / target;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.tokens.cardBg.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.tokens.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tokens.primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(a.icon, color: tokens.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(a.title,
                            style: TextStyle(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.w900)),
                      ),
                      Text(
                        done ? '完成' : '${a.current}/$target',
                        style: TextStyle(
                            color: tokens.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(a.desc,
                      style:
                          TextStyle(color: tokens.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: done ? 1 : p,
                      minHeight: 8,
                      backgroundColor: tokens.chipBg,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ach {
  final String title;
  final String desc;
  final int current;
  final List<int> targets;
  final IconData icon;

  _Ach({
    required this.title,
    required this.desc,
    required this.current,
    required this.targets,
    required this.icon,
  });

  int? nextTarget() {
    for (final t in targets) {
      if (current < t) return t;
    }
    return null;
  }
}
