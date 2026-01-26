import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_tokens.dart';
import '../../app_card.dart';

import '../../../bubble_library/providers/providers.dart';
import '../../../collections/wishlist_provider.dart';
import '../../../pages/product_page.dart';

class MeDashboardSection extends ConsumerWidget {
  const MeDashboardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;

    // 未登入：顯示簡易提示（不要炸）
    String? uid;
    try {
      uid = ref.read(uidProvider);
    } catch (_) {
      uid = null;
    }

    if (uid == null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('學習儀表板',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: tokens.textPrimary)),
            const SizedBox(height: 8),
            Text('登入後可看到：已購買/最愛/推播中/最近開啟與偏好類別',
                style: TextStyle(color: tokens.textSecondary)),
          ],
        ),
      );
    }

    final libAsync = ref.watch(libraryProductsProvider);
    final wishAsync = ref.watch(localWishlistProvider);
    final productsMapAsync = ref.watch(productsMapProvider);
    final globalPushAsync = ref.watch(globalPushSettingsProvider);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('學習儀表板',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: tokens.textPrimary)),
          const SizedBox(height: 12),
          productsMapAsync.when(
            data: (productsMap) {
              return globalPushAsync.when(
                data: (globalPush) {
                  return libAsync.when(
                    data: (lib) {
                      return wishAsync.when(
                        data: (wish) {
                          final purchased = lib.where((e) {
                            try {
                              return (e as dynamic).isHidden != true &&
                                  productsMap.containsKey(
                                      (e as dynamic).productId.toString());
                            } catch (_) {
                              return false;
                            }
                          }).toList();

                          final wishlist = wish.where((w) {
                            try {
                              return productsMap
                                  .containsKey((w as dynamic).productId.toString());
                            } catch (_) {
                              return false;
                            }
                          }).toList();

                          // 計算推播中數量：需要同時檢查全域推播開關和個別商品推播開關
                          final pushingCount = purchased.where((e) {
                            try {
                              return globalPush.enabled &&
                                  (e as dynamic).pushEnabled == true;
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
                      for (final w in wishlist) {
                        try {
                          if ((w as dynamic).isFavorite == true) {
                            favIds.add((w as dynamic).productId.toString());
                          }
                        } catch (_) {}
                      }

                      // 最近開啟 Top 3
                      final recent = [...purchased];
                      recent.sort((a, b) {
                        DateTime ta;
                        DateTime tb;
                        try {
                          ta = ((a as dynamic).lastOpenedAt as DateTime?) ??
                              ((a as dynamic).purchasedAt as DateTime);
                        } catch (_) {
                          ta = DateTime.fromMillisecondsSinceEpoch(0);
                        }
                        try {
                          tb = ((b as dynamic).lastOpenedAt as DateTime?) ??
                              ((b as dynamic).purchasedAt as DateTime);
                        } catch (_) {
                          tb = DateTime.fromMillisecondsSinceEpoch(0);
                        }
                        return tb.compareTo(ta);
                      });
                      final recentTop = recent.take(3).toList();

                      // Top 類別（用 productId 前綴統計，因 bubble_library Product 無 topicId）
                      final topicCount = <String, int>{};
                      void addTopic(String pid) {
                        final p = productsMap[pid];
                        if (p == null) return;
                        // 嘗試從 title 取前綴作為類別（fallback）
                        final tid = p.title.split(' ').first;
                        if (tid.isEmpty) return;
                        topicCount[tid] = (topicCount[tid] ?? 0) + 1;
                      }

                      for (final lp in purchased) {
                        try {
                          addTopic((lp as dynamic).productId.toString());
                        } catch (_) {}
                      }
                      for (final w in wishlist) {
                        try {
                          addTopic((w as dynamic).productId.toString());
                        } catch (_) {}
                      }

                      final topTopics = topicCount.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));
                      final top3 = topTopics.take(3).toList();

                      // 小目標進度（示意但是真計數）
                      // 例：本週目標：收藏/解鎖 10 個泡泡（用 purchased+wishlist）
                      final totalOwnedOrSaved =
                          purchased.length + wishlist.length;
                      const goal = 10;
                      final progress = totalOwnedOrSaved.clamp(0, goal) / goal;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kpiRow(
                            context,
                            items: [
                              _Kpi('已購買', purchased.length),
                              _Kpi('願望清單', wishlist.length),
                              _Kpi('最愛', favIds.length),
                              _Kpi('推播中', pushingCount),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text('小目標',
                              style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                              backgroundColor: tokens.chipBg,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                              '收藏/解鎖 $totalOwnedOrSaved / $goal（可之後改成 streak 或本週學習量）',
                              style: TextStyle(
                                  color: tokens.textSecondary, fontSize: 12)),
                          const SizedBox(height: 16),
                          if (recentTop.isNotEmpty) ...[
                            Text('最近開啟',
                                style: TextStyle(
                                    color: tokens.textSecondary,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            ...recentTop.map((lp) {
                              final pid = (lp as dynamic).productId.toString();
                              final title = productsMap[pid]?.title ?? pid;
                              final sub = _recentSubtitle(lp, globalPushEnabled: globalPush.enabled);
                              return _recentTile(
                                context,
                                title: title,
                                subtitle: sub,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ProductPage(productId: pid),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 14),
                          ],
                          if (top3.isNotEmpty) ...[
                            Text('你最常看的類別',
                                style: TextStyle(
                                    color: tokens.textSecondary,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: top3.map((e) {
                                return _chip(context, '${e.key} · ${e.value}');
                              }).toList(),
                            ),
                          ],
                        ],
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
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('global push error: $e',
                    style: TextStyle(color: tokens.textSecondary)),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('products error: $e',
                style: TextStyle(color: tokens.textSecondary)),
          ),
        ],
      ),
    );
  }

  String _recentSubtitle(dynamic lp, {required bool globalPushEnabled}) {
    // 不靠 Excel：用 pushEnabled / purchasedAt / lastOpenedAt 組一個資訊密度
    String whenText(DateTime? dt) {
      if (dt == null) return '';
      String two(int v) => v.toString().padLeft(2, '0');
      return '${dt.month}/${dt.day} ${two(dt.hour)}:${two(dt.minute)}';
    }

    DateTime? opened;
    DateTime? purchased;
    bool itemPushEnabled = false;

    try {
      opened = (lp.lastOpenedAt as DateTime?);
    } catch (_) {}
    try {
      purchased = (lp.purchasedAt as DateTime?);
    } catch (_) {}
    try {
      itemPushEnabled = (lp.pushEnabled == true);
    } catch (_) {}

    // 推播狀態：需要全域推播開關和個別商品推播開關都啟用才算推播中
    final pushing = globalPushEnabled && itemPushEnabled;

    final parts = <String>[];
    if (opened != null) parts.add('上次：${whenText(opened)}');
    if (purchased != null) parts.add('購買：${whenText(purchased)}');
    parts.add(pushing ? '推播中' : '推播關閉');
    return parts.join(' · ');
  }

  Widget _kpiRow(BuildContext context, {required List<_Kpi> items}) {
    final tokens = context.tokens;
    return Row(
      children: items.map((e) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.tokens.cardBg.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.tokens.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${e.value}',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: tokens.textPrimary)),
                const SizedBox(height: 6),
                Text(e.label,
                    style:
                        TextStyle(color: tokens.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _recentTile(BuildContext context,
      {required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tokens.primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.history, color: tokens.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: tokens.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: tokens.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String text) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: tokens.chipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.cardBorder),
      ),
      child:
          Text(text, style: TextStyle(color: tokens.textPrimary, fontSize: 12)),
    );
  }
}

class _Kpi {
  final String label;
  final int value;
  const _Kpi(this.label, this.value);
}
