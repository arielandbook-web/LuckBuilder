import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../models/product.dart';
import '../models/user_library.dart';
import '../notifications/scheduled_push_cache.dart';
import 'product_library_page.dart';
import 'push_center_page.dart';
import 'push_product_config_page.dart';
import 'widgets/bubble_card.dart';
import '../../widgets/rich_sections/sections/library_rich_card.dart';
import '../../widgets/rich_sections/user_learning_store.dart';
import '../../../theme/app_tokens.dart';
import '../../collections/wishlist_provider.dart';
import '../../pages/product_page.dart';

/// 讀取本機快取的未來 3 天推播排程（不依賴 Firestore）
final _scheduledCacheProvider =
    FutureProvider<List<ScheduledPushEntry>>((ref) async {
  return ScheduledPushCache()
      .loadSortedUpcoming(horizon: const Duration(days: 3));
});

/// 本週完成度（過去 7 天含今天）
final weeklyCountProvider =
    FutureProvider.family<int, String>((ref, productId) async {
  return UserLearningStore().weeklyCount(productId);
});

enum LibraryTab { purchased, wishlist, favorites }

class BubbleLibraryPage extends ConsumerStatefulWidget {
  const BubbleLibraryPage({super.key});

  @override
  ConsumerState<BubbleLibraryPage> createState() => _BubbleLibraryPageState();
}

class _BubbleLibraryPageState extends ConsumerState<BubbleLibraryPage> {
  LibraryTab tab = LibraryTab.purchased;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsMapProvider);

    // 檢查是否登入，未登入時顯示提示
    try {
      ref.read(uidProvider);
    } catch (_) {
      return Scaffold(
        appBar: AppBar(title: const Text('泡泡庫')),
        body: const Center(child: Text('請先登入以使用泡泡庫功能')),
      );
    }

    final libAsync = ref.watch(libraryProductsProvider);
    final wishAsync = ref.watch(localWishlistProvider);
    final scheduledAsync = ref.watch(_scheduledCacheProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('泡泡庫'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PushCenterPage())),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SegmentedButton<LibraryTab>(
              segments: const [
                ButtonSegment(value: LibraryTab.purchased, label: Text('已購買')),
                ButtonSegment(value: LibraryTab.wishlist, label: Text('未購買收藏')),
                ButtonSegment(value: LibraryTab.favorites, label: Text('我的最愛')),
              ],
              selected: {tab},
              onSelectionChanged: (s) => setState(() => tab = s.first),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: productsAsync.when(
              data: (productsMap) {
                return libAsync.when(
                  data: (lib) {
                    return wishAsync.when(
                      data: (wishItems) {
                        final visibleLib = lib
                            .where((e) =>
                                !e.isHidden &&
                                productsMap.containsKey(e.productId))
                            .toList();

                        // 取得排程快取（純本機，不影響資料流）
                        final scheduled = scheduledAsync.asData?.value ??
                            <ScheduledPushEntry>[];

                        if (tab == LibraryTab.purchased) {
                          return _buildPurchasedTab(
                              context, visibleLib, productsMap, scheduled);
                        }

                        if (tab == LibraryTab.wishlist) {
                          return _buildWishlistTab(
                              context, wishItems, productsMap);
                        }

                        // Favorites
                        // 注意：Favorites 需要從 Firestore wishlist 取得，這裡暫時用空列表
                        return _buildFavoritesTab(
                            context, visibleLib, [], productsMap);
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) =>
                          Center(child: Text('wishlist error: $e')),
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
          ),
        ],
      ),
    );
  }

  Widget _buildPurchasedTab(
    BuildContext context,
    List<dynamic> visibleLib,
    Map<String, Product> productsMap,
    List<ScheduledPushEntry> scheduled,
  ) {
    // Helper: 根據 productId 找最早的排程項目
    ScheduledPushEntry? nextEntryFor(String productId) {
      final list = scheduled
          .where((s) => s.payload['productId']?.toString() == productId)
          .toList();
      if (list.isEmpty) return null;
      list.sort((a, b) => a.when.compareTo(b.when));
      return list.first;
    }

    String fmtNextTime(DateTime dt) {
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    String? extractDayFromBody(String body) {
      final firstLine = body.split('\n').first;
      final m = RegExp(r'Day\s+(\d+)/365').firstMatch(firstLine);
      return m?.group(1);
    }

    String latestTitleText(ScheduledPushEntry e) {
      final day = extractDayFromBody(e.body);
      return day == null ? '下一則：${e.title}' : '下一則：${e.title}（Day $day）';
    }

    if (visibleLib.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 64, color: Colors.white.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              '目前沒有已購買的商品',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8), fontSize: 16),
            ),
          ],
        ),
      );
    }
    visibleLib.sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt));
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: visibleLib.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final lp = visibleLib[i];
        final product = productsMap[lp.productId]!;
        final tokens = ctx.tokens;
        final entry = nextEntryFor(lp.productId);

        // 本週完成度（真資料）
        final weeklyAsync = ref.watch(weeklyCountProvider(lp.productId));
        final weeklyText = weeklyAsync.when(
          data: (c) => '本週完成度：$c/7',
          loading: () => '本週完成度：…',
          error: (_, __) => '本週完成度：—',
        );

        return LibraryRichCard(
          title: product.title,
          subtitle: 'Day ${lp.progress.nextSeq}/365',
          coverImageUrl: null,
          nextPushText: lp.pushEnabled
              ? (entry == null
                  ? '未來 3 天尚未排程'
                  : '下一則：${fmtNextTime(entry.when)}')
              : '推播已關閉',
          weeklyProgress: weeklyText,
          latestTitle: entry == null ? '下一則：尚未排程' : latestTitleText(entry),
          headerTrailing: PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz, color: tokens.textSecondary),
            onSelected: (v) async {
              final repo = ref.read(libraryRepoProvider);
              final uid2 = ref.read(uidProvider);
              if (v == 'fav') {
                await repo.setProductFavorite(
                    uid2, lp.productId, !lp.isFavorite);
              } else if (v == 'push') {
                // ignore: use_build_context_synchronously
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      PushProductConfigPage(productId: lp.productId),
                ));
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'fav',
                child: Row(
                  children: [
                    Icon(lp.isFavorite ? Icons.star : Icons.star_border),
                    const SizedBox(width: 10),
                    Text(lp.isFavorite ? '移除最愛' : '加入最愛'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'push',
                child: Row(
                  children: [
                    Icon(Icons.notifications_active_outlined),
                    SizedBox(width: 10),
                    Text('推播設定'),
                  ],
                ),
              ),
            ],
          ),
          onLearnNow: () async {
            await UserLearningStore().markLearnedTodayAndGlobal(lp.productId);
            ref.invalidate(weeklyCountProvider(lp.productId));
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('已記錄：今天完成 1 次學習')));
          },
          onMakeUpToday: () {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('補學今天（示意）')));
          },
          onPreview3Days: () {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('預覽未來 3 天（示意）')));
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PushProductConfigPage(productId: lp.productId),
            ));
          },
          onTap: () async {
            await UserLearningStore().markLearnedTodayAndGlobal(lp.productId);
            ref.invalidate(weeklyCountProvider(lp.productId));
            await ref
                .read(libraryRepoProvider)
                .touchLastOpened(ref.read(uidProvider), lp.productId);
            // ignore: use_build_context_synchronously
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ProductLibraryPage(
                  productId: lp.productId, isWishlistPreview: false),
            ));
          },
        );
      },
    );
  }

  Widget _buildWishlistTab(
    BuildContext context,
    List<WishlistItem> wishItems,
    Map<String, Product> productsMap,
  ) {
    final visibleWish = <WishlistItem>[
      ...wishItems.where((e) => productsMap.containsKey(e.productId))
    ]..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    if (visibleWish.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border,
                size: 64, color: Colors.white.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              '目前沒有未購買收藏',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8), fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '到商品頁點「收藏」即可加入',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: visibleWish.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final w = visibleWish[i];
        final p = productsMap[w.productId]!;
        final title = p.title;

        Widget _chip(String label) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withValues(alpha: 0.1),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          );
        }

        return BubbleCard(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ProductLibraryPage(
                productId: w.productId,
                isWishlistPreview: true, // ✅ 試讀模式
              ),
            ));
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                        IconButton(
                          tooltip: '最愛',
                          icon: Icon(w.isFavorite
                              ? Icons.star
                              : Icons.star_border),
                          onPressed: () => ref
                              .read(localWishlistNotifierProvider)
                              .toggleFavorite(w.productId),
                        ),
                        IconButton(
                          tooltip: '移除收藏',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => ref
                              .read(localWishlistNotifierProvider)
                              .remove(w.productId),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        _chip('未購買'),
                        _chip('試讀可用'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ProductLibraryPage(
                                productId: w.productId,
                                isWishlistPreview: true,
                              ),
                            ));
                          },
                          child: const Text('試讀'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ProductPage(productId: w.productId),
                            ));
                          },
                          child: const Text('立即購買'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFavoritesTab(
    BuildContext context,
    List<UserLibraryProduct> visibleLib,
    List<WishlistItem> visibleWish,
    Map<String, Product> productsMap,
  ) {
    final favPids = <String>{};
    for (final lp in visibleLib) {
      if (lp.isFavorite) favPids.add(lp.productId);
    }
    for (final w in visibleWish) {
      if (w.isFavorite) favPids.add(w.productId);
    }

    final favList = favPids.toList();

    if (favList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_border,
                size: 64, color: Colors.white.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              '目前沒有最愛',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8), fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '點擊商品旁的 ⭐ 按鈕來加入最愛',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: favList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final pid = favList[i];
        final title = productsMap[pid]!.title;
        final lp = visibleLib.where((e) => e.productId == pid).firstOrNull;
        final isPurchased = lp != null;

        return BubbleCard(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ProductLibraryPage(
                  productId: pid, isWishlistPreview: !isPurchased),
            ));
          },
          child: Row(
            children: [
              const Icon(Icons.star, size: 20),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700))),
              Text(isPurchased ? '已購買' : '未購買',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
            ],
          ),
        );
      },
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
