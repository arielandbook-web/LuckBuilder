import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_tokens.dart';
import '../../app_card.dart';

import '../../../providers/v2_providers.dart';
import '../../../bubble_library/providers/providers.dart'
    show uidProvider, libraryProductsProvider, wishlistProvider;
import '../../../data/models.dart';
import '../../../pages/product_page.dart';
import '../../../pages/product_list_page.dart';

class CategoryNetflixRailsSection extends ConsumerWidget {
  const CategoryNetflixRailsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;

    final productsMapAsync = ref.watch(allProductsMapProvider);
    final hotAsync = ref.watch(featuredProductsProvider('hot_all'));
    final weeklyAsync = ref.watch(featuredProductsProvider('weekly_pick'));
    final segSelected = ref.watch(selectedSegmentProvider);
    final topicsAsync = ref.watch(topicsForSelectedSegmentProvider);

    final libAsync = _safeLib(ref);
    final wishAsync = _safeWish(ref);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('探索推薦',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: tokens.textPrimary)),
        const SizedBox(height: 10),

        // 你最近常看 / 你可能想試（用真資料推）
        AppCard(
          padding: const EdgeInsets.all(14),
          child: productsMapAsync.when(
            data: (productsMap) {
              return libAsync.when(
                data: (lib) {
                  return wishAsync.when(
                    data: (wish) {
                      final recentTopics =
                          _recentTopics(productsMap, lib).take(3).toList();
                      final maybeTry = _maybeTryTopics(productsMap, lib, wish)
                          .take(3)
                          .toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('你最近常看',
                              style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          if (recentTopics.isEmpty)
                            Text('先開啟幾個商品，我會把常看的類別放在這裡',
                                style: TextStyle(color: tokens.textSecondary))
                          else
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: recentTopics
                                  .map((t) => _topicChip(context, t, onTap: () {
                                        // 直接跳該 topic 的商品列表
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ProductListPage(topicId: t),
                                          ),
                                        );
                                      }))
                                  .toList(),
                            ),
                          const SizedBox(height: 14),
                          Text('你可能想試',
                              style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          if (maybeTry.isEmpty)
                            Text('收藏/願望清單再多一點，這裡會變成「擴展興趣圈」',
                                style: TextStyle(color: tokens.textSecondary))
                          else
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: maybeTry
                                  .map((t) => _topicChip(context, t, onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ProductListPage(topicId: t),
                                          ),
                                        );
                                      }))
                                  .toList(),
                            ),
                        ],
                      );
                    },
                    loading: () => const SizedBox(
                        height: 60,
                        child: Center(child: CircularProgressIndicator())),
                    error: (e, _) => Text('wishlist error: $e',
                        style: TextStyle(color: tokens.textSecondary)),
                  );
                },
                loading: () => const SizedBox(
                    height: 60,
                    child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text('library error: $e',
                    style: TextStyle(color: tokens.textSecondary)),
              );
            },
            loading: () => const SizedBox(
                height: 60, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('products error: $e',
                style: TextStyle(color: tokens.textSecondary)),
          ),
        ),

        const SizedBox(height: 16),

        // Rail 1：新上架（真資料：用 productsMap 推，盡力找 createdAt/updatedAt/order）
        _sectionTitle(context, '新上架'),
        const SizedBox(height: 10),
        productsMapAsync.when(
          data: (productsMap) {
            final list = productsMap.values.toList();
            list.sort((a, b) => _newerFirst(a, b));
            final top = list.take(12).toList();
            if (top.isEmpty) {
              return _emptyCard(context, '新上架：目前沒有資料');
            }
            return _rail(context, top);
          },
          loading: () => const SizedBox(
              height: 190, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => _emptyCard(context, '新上架：讀取錯誤 $e'),
        ),

        const SizedBox(height: 18),

        // Rail 2：最多人解鎖（熱門）
        _sectionTitle(context, '最多人解鎖'),
        const SizedBox(height: 10),
        hotAsync.when(
          data: (ps) => ps.isEmpty
              ? _emptyCard(context, '熱門：無資料')
              : _rail(context, ps.take(12).toList()),
          loading: () => const SizedBox(
              height: 190, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => _emptyCard(context, '熱門：讀取錯誤 $e'),
        ),

        const SizedBox(height: 18),

        // Rail 3：適合你（用 library/wishlist 的 topic 偏好 + 最愛/推播/最近開啟加權）
        _sectionTitle(context, '適合你'),
        const SizedBox(height: 10),
        productsMapAsync.when(
          data: (productsMap) {
            return libAsync.when(
              data: (lib) {
                return wishAsync.when(
                  data: (wish) {
                    final list = _forYouProducts(productsMap, lib, wish)
                        .take(12)
                        .toList();
                    if (list.isEmpty) {
                      // fallback：週精選
                      return weeklyAsync.when(
                        data: (ps) => ps.isEmpty
                            ? _emptyCard(context, '適合你：先收藏/購買幾個商品')
                            : _rail(context, ps.take(12).toList()),
                        loading: () => const SizedBox(
                            height: 190,
                            child: Center(child: CircularProgressIndicator())),
                        error: (e, _) => _emptyCard(context, '適合你：讀取錯誤 $e'),
                      );
                    }
                    return _rail(context, list);
                  },
                  loading: () => const SizedBox(
                      height: 190,
                      child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => _emptyCard(context, '適合你：讀取錯誤 $e'),
                );
              },
              loading: () => const SizedBox(
                  height: 190,
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => _emptyCard(context, '適合你：讀取錯誤 $e'),
            );
          },
          loading: () => const SizedBox(
              height: 190, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => _emptyCard(context, '適合你：讀取錯誤 $e'),
        ),

        const SizedBox(height: 18),

        // 學習路徑 / 入門包（先做 UI + 真 topics；不需後端）
        _sectionTitle(context, '入門包'),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                segSelected == null ? '從你目前的分類開始' : '從「${segSelected.title}」開始',
                style: TextStyle(
                    color: tokens.textPrimary, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              topicsAsync.when(
                data: (ts) {
                  if (ts.isEmpty) {
                    return Text('此分類目前沒有 topics（請檢查 Firestore topics）',
                        style: TextStyle(color: tokens.textSecondary));
                  }
                  final top = ts.take(3).toList();
                  return Column(
                    children: top.map((t) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => ProductListPage(topicId: t.id)),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.10)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color:
                                        tokens.primary.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.play_arrow,
                                      color: tokens.primary),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(t.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: tokens.textPrimary,
                                          fontWeight: FontWeight.w800)),
                                ),
                                Icon(Icons.chevron_right,
                                    color: tokens.textSecondary),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('入門包讀取錯誤：$e',
                    style: TextStyle(color: tokens.textSecondary)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- Data helpers ----------

  AsyncValue<List<dynamic>> _safeLib(WidgetRef ref) {
    try {
      ref.read(uidProvider);
      return ref.watch(libraryProductsProvider);
    } catch (_) {
      return const AsyncValue.data(<dynamic>[]);
    }
  }

  AsyncValue<List<dynamic>> _safeWish(WidgetRef ref) {
    try {
      ref.read(uidProvider);
      return ref.watch(wishlistProvider);
    } catch (_) {
      return const AsyncValue.data(<dynamic>[]);
    }
  }

  // 新上架排序：盡量找 createdAt/updatedAt/order；沒有就保持穩定 fallback
  int _newerFirst(Product a, Product b) {
    // fallback：用 id 字串
    return b.id.compareTo(a.id);
  }

  // 最近常看 topics：用 library.lastOpenedAt/purchasedAt 推 topicId
  List<String> _recentTopics(
      Map<String, Product> productsMap, List<dynamic> lib) {
    final items = lib.where((lp) {
      try {
        if ((lp as dynamic).isHidden == true) return false;
        return productsMap.containsKey((lp as dynamic).productId.toString());
      } catch (_) {
        return false;
      }
    }).toList();

    items.sort((a, b) {
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

    final seen = <String>{};
    final out = <String>[];
    for (final lp in items) {
      final pid = (lp as dynamic).productId.toString();
      final p = productsMap[pid];
      if (p == null) continue;
      final tid = p.topicId;
      if (seen.add(tid)) out.add(tid);
      if (out.length >= 6) break;
    }
    return out;
  }

  // 可能想試：找 wishlist topics + 排除最近常看
  List<String> _maybeTryTopics(
      Map<String, Product> productsMap, List<dynamic> lib, List<dynamic> wish) {
    final recent = _recentTopics(productsMap, lib).toSet();
    final count = <String, int>{};

    for (final w in wish) {
      try {
        final pid = (w as dynamic).productId.toString();
        final p = productsMap[pid];
        if (p == null) continue;
        final tid = p.topicId;
        if (recent.contains(tid)) continue;
        count[tid] = (count[tid] ?? 0) + 1;
      } catch (_) {}
    }

    final list = count.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list.map((e) => e.key).toList();
  }

  // 適合你：用 topic 偏好加權，挑出產品
  List<Product> _forYouProducts(
      Map<String, Product> productsMap, List<dynamic> lib, List<dynamic> wish) {
    final topicScore = <String, int>{};

    void addTopic(String pid, int w) {
      final p = productsMap[pid];
      if (p == null) return;
      topicScore[p.topicId] = (topicScore[p.topicId] ?? 0) + w;
    }

    // library：推播/最愛/最近開啟 加權
    for (final lp in lib) {
      try {
        if ((lp as dynamic).isHidden == true) continue;
        final pid = (lp as dynamic).productId.toString();
        addTopic(pid, 2);
        if ((lp as dynamic).pushEnabled == true) addTopic(pid, 5);
        if ((lp as dynamic).isFavorite == true) addTopic(pid, 4);
      } catch (_) {}
    }

    // wishlist：加一點權重
    for (final w in wish) {
      try {
        final pid = (w as dynamic).productId.toString();
        addTopic(pid, 1);
        if ((w as dynamic).isFavorite == true) addTopic(pid, 2);
      } catch (_) {}
    }

    if (topicScore.isEmpty) return <Product>[];

    // 依 topicScore 取產品，排除你已擁有/願望清單的 pid（讓推薦更像探索）
    final owned = <String>{};
    for (final lp in lib) {
      try {
        owned.add((lp as dynamic).productId.toString());
      } catch (_) {}
    }
    for (final w in wish) {
      try {
        owned.add((w as dynamic).productId.toString());
      } catch (_) {}
    }

    final candidates =
        productsMap.values.where((p) => !owned.contains(p.id)).toList();

    candidates.sort((a, b) {
      final sa = topicScore[a.topicId] ?? 0;
      final sb = topicScore[b.topicId] ?? 0;
      final cmp = sb.compareTo(sa);
      if (cmp != 0) return cmp;
      return _newerFirst(a, b);
    });

    return candidates;
  }

  // ---------- UI helpers ----------

  Widget _sectionTitle(BuildContext context, String title) {
    final tokens = context.tokens;
    return Text('│ $title',
        style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: tokens.textPrimary));
  }

  Widget _emptyCard(BuildContext context, String text) {
    final tokens = context.tokens;
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(text, style: TextStyle(color: tokens.textSecondary)),
      ),
    );
  }

  Widget _topicChip(BuildContext context, String text,
      {required VoidCallback onTap}) {
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: tokens.chipBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: tokens.cardBorder),
        ),
        child: Text(text,
            style: TextStyle(color: tokens.textPrimary, fontSize: 12)),
      ),
    );
  }

  Widget _rail(BuildContext context, List<Product> products) {
    final tokens = context.tokens;
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final p = products[i];
          return SizedBox(
            width: 280,
            child: AppCard(
              padding: EdgeInsets.zero,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProductPage(productId: p.id),
              )),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.coverImageUrl != null && p.coverImageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                      child: Image.network(
                        p.coverImageUrl!,
                        height: 110,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 110,
                          color: tokens.chipBg,
                          child: Icon(Icons.image_not_supported,
                              color: tokens.textSecondary),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: tokens.textPrimary)),
                          const SizedBox(height: 6),
                          Text('${p.topicId} · ${p.level}',
                              style: TextStyle(
                                  color: tokens.textSecondary, fontSize: 12)),
                          if (p.levelGoal != null &&
                              p.levelGoal!.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(p.levelGoal!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: tokens.textSecondary, fontSize: 12)),
                          ],
                          const Spacer(),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text('查看 ›',
                                style: TextStyle(
                                    color: tokens.primary,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
