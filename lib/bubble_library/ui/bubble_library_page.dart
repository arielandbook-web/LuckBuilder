import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../models/product.dart';
import '../models/user_library.dart';
import '../models/content_item.dart';
import '../notifications/scheduled_push_cache.dart';
import '../notifications/push_orchestrator.dart';
import '../../notifications/push_timeline_provider.dart';
import 'product_library_page.dart';
import 'push_center_page.dart';
import 'push_product_config_page.dart';
import 'detail_page.dart';
import 'widgets/bubble_card.dart';
import '../../widgets/rich_sections/sections/library_rich_card.dart';
import '../../widgets/rich_sections/user_learning_store.dart';
import '../../../theme/app_tokens.dart';
import '../../collections/wishlist_provider.dart';
import '../../pages/product_page.dart';
import '../../notifications/favorite_sentences_store.dart';

/// 本週完成度（過去 7 天含今天）
final weeklyCountProvider =
    FutureProvider.family<int, String>((ref, productId) async {
  return UserLearningStore().weeklyCount(productId);
});

enum LibraryView { purchased, wishlist, favorites, history, favoriteSentences }

class BubbleLibraryPage extends ConsumerStatefulWidget {
  const BubbleLibraryPage({super.key});

  @override
  ConsumerState<BubbleLibraryPage> createState() => _BubbleLibraryPageState();
}

class _BubbleLibraryPageState extends ConsumerState<BubbleLibraryPage> {
  LibraryView currentView = LibraryView.purchased;
  DateTime? _lastRescheduleTime;
  
  // ✅ 階段 4：搜尋/篩選狀態
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedProductIds = {};
  int _selectedHistoryTab = 0; // 0 = 待學習, 1 = 已學習

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
    final scheduledAsync = ref.watch(scheduledCacheProvider);

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
      drawer: _buildDrawer(),
      body: productsAsync.when(
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

                  return _buildBody(
                    context,
                    visibleLib,
                    wishItems,
                    productsMap,
                    scheduled,
                  );
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
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            ),
            child: const Text(
              '泡泡庫',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2),
            title: const Text('已購買產品'),
            selected: currentView == LibraryView.purchased,
            onTap: () {
              Navigator.pop(context);
              setState(() => currentView = LibraryView.purchased);
            },
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_border),
            title: const Text('未購買收藏'),
            selected: currentView == LibraryView.wishlist,
            onTap: () {
              Navigator.pop(context);
              setState(() => currentView = LibraryView.wishlist);
            },
          ),
          ListTile(
            leading: const Icon(Icons.star_border),
            title: const Text('我的最愛'),
            selected: currentView == LibraryView.favorites,
            onTap: () {
              Navigator.pop(context);
              setState(() => currentView = LibraryView.favorites);
            },
          ),
          ListTile(
            leading: const Icon(Icons.history_edu),
            title: const Text('學習歷史'),
            selected: currentView == LibraryView.history,
            onTap: () {
              Navigator.pop(context);
              setState(() => currentView = LibraryView.history);
            },
          ),
          ListTile(
            leading: const Icon(Icons.format_quote),
            title: const Text('收藏今日一句'),
            selected: currentView == LibraryView.favoriteSentences,
            onTap: () {
              Navigator.pop(context);
              setState(() => currentView = LibraryView.favoriteSentences);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<UserLibraryProduct> visibleLib,
    List<WishlistItem> wishItems,
    Map<String, Product> productsMap,
    List<ScheduledPushEntry> scheduled,
  ) {
    switch (currentView) {
      case LibraryView.purchased:
        return _buildPurchasedTab(
            context, visibleLib, productsMap, scheduled);
      case LibraryView.wishlist:
        return _buildWishlistTab(context, wishItems, productsMap);
      case LibraryView.favorites:
        return _buildFavoritesTab(context, visibleLib, wishItems, productsMap);
      case LibraryView.history:
        return _buildHistoryView(context);
      case LibraryView.favoriteSentences:
        return _buildFavoriteSentencesTab(context);
    }
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

        Widget chip(String label) {
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
                        chip('未購買'),
                        chip('試讀可用'),
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

  Widget _buildHistoryView(BuildContext context) {
    final savedAsync = ref.watch(savedItemsProvider);
    final productsAsync = ref.watch(productsMapProvider);

    return savedAsync.when(
      data: (savedMap) {
        return productsAsync.when(
          data: (productsMap) {
            // ✅ 階段 1：數據重組 - 依產品分組
            // 先批次載入所有 ContentItem
            final allContentIds = savedMap.keys.toList();
            if (allContentIds.isEmpty) {
              return _buildEmptyHistory();
            }

            return FutureBuilder<Map<String, ContentItem>>(
              future: _loadAllContentItems(allContentIds),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('載入錯誤: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red)),
                  );
                }

                final contentItemsMap = snapshot.data ?? {};
                
                // 依產品分組，每個產品內再分已學習/待學習
                final groupedByProduct = <String, Map<String, List<String>>>{};

                for (final entry in savedMap.entries) {
                  final contentId = entry.key;
                  final contentItem = contentItemsMap[contentId];
                  if (contentItem == null) continue;

                  final productId = contentItem.productId;
                  groupedByProduct.putIfAbsent(
                    productId,
                    () => {'toLearn': <String>[], 'learned': <String>[]},
                  );

                  if (entry.value.learned) {
                    groupedByProduct[productId]!['learned']!.add(contentId);
                  } else {
                    groupedByProduct[productId]!['toLearn']!.add(contentId);
                  }
                }

                // 排序：依產品名稱
                final sortedProducts = groupedByProduct.keys.toList()
                  ..sort((a, b) {
                    final titleA = productsMap[a]?.title ?? '';
                    final titleB = productsMap[b]?.title ?? '';
                    return titleA.compareTo(titleB);
                  });

                // ✅ 階段 4：應用搜尋/篩選
                final searchQuery = _searchController.text.trim();
                final filteredProducts = sortedProducts.where((productId) {
                  if (!_matchesFilter(productId)) return false;
                  if (searchQuery.isEmpty) return true;
                  
                  final group = groupedByProduct[productId]!;
                  final allContentIds = [
                    ...group['toLearn']!,
                    ...group['learned']!,
                  ];
                  
                  return allContentIds.any((contentId) {
                    final contentItem = contentItemsMap[contentId];
                    if (contentItem == null) return false;
                    final product = productsMap[productId];
                    return _matchesSearch(searchQuery, contentItem, product);
                  });
                }).toList();

                return _buildHistoryContentGrouped(
                  context,
                  filteredProducts,
                  groupedByProduct,
                  contentItemsMap,
                  productsMap,
                  searchQuery,
                  _selectedHistoryTab == 0, // showToLearn: true = 待學習, false = 已學習
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('products error: $e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('saved items error: $e')),
    );
  }

  // 批次載入所有 ContentItem
  Future<Map<String, ContentItem>> _loadAllContentItems(
      List<String> contentIds) async {
    final futures = contentIds.map((id) async {
      try {
        final item = await ref.read(contentItemProvider(id).future);
        return MapEntry(id, item);
      } catch (e) {
        debugPrint('載入 ContentItem $id 失敗: $e');
        return null;
      }
    });

    final results = await Future.wait(futures);
    return {
      for (final entry in results)
        if (entry != null) entry.key: entry.value
    };
  }

  Widget _buildEmptyHistory() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_edu,
              size: 64, color: Colors.white.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            '目前沒有學習歷史',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8), fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '開始學習內容後，記錄會顯示在這裡',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ✅ 階段 2-3：按產品分組顯示 + 性能優化（ListView.builder）
  Widget _buildHistoryContentGrouped(
    BuildContext context,
    List<String> sortedProducts,
    Map<String, Map<String, List<String>>> groupedByProduct,
    Map<String, ContentItem> contentItemsMap,
    Map<String, Product> productsMap,
    String searchQuery,
    bool showToLearn,
  ) {
    // 建立扁平化列表：用於 ListView.builder
    final flatItems = <_HistoryListItem>[];
    
    if (showToLearn) {
      // 待學習區塊
      final toLearnProducts = sortedProducts
          .where((pid) => groupedByProduct[pid]!['toLearn']!.isNotEmpty)
          .toList();
      for (final productId in toLearnProducts) {
        final toLearnIds = groupedByProduct[productId]!['toLearn']!
            .where((contentId) {
              if (searchQuery.isEmpty) return true;
              final contentItem = contentItemsMap[contentId];
              if (contentItem == null) return false;
              final product = productsMap[productId];
              return _matchesSearch(searchQuery, contentItem, product);
            })
            .toList();
        final learnedIds = groupedByProduct[productId]!['learned']!;
        
        if (toLearnIds.isNotEmpty || learnedIds.isNotEmpty) {
          flatItems.add(_HistoryListItem.productHeader(
            productId,
            toLearnIds.length,
            learnedIds.length,
          ));
        }
      }
    } else {
      // 已學習區塊
      final learnedProducts = sortedProducts
          .where((pid) => groupedByProduct[pid]!['learned']!.isNotEmpty)
          .toList();
      for (final productId in learnedProducts) {
        final toLearnIds = groupedByProduct[productId]!['toLearn']!;
        final learnedIds = groupedByProduct[productId]!['learned']!
            .where((contentId) {
              if (searchQuery.isEmpty) return true;
              final contentItem = contentItemsMap[contentId];
              if (contentItem == null) return false;
              final product = productsMap[productId];
              return _matchesSearch(searchQuery, contentItem, product);
            })
            .toList();
        
        if (toLearnIds.isNotEmpty || learnedIds.isNotEmpty) {
          flatItems.add(_HistoryListItem.productHeader(
            productId,
            toLearnIds.length,
            learnedIds.length,
          ));
        }
      }
    }

    // 使用 ListView.builder 優化性能
    return Column(
      children: [
        // ✅ 階段 4：搜尋/篩選 UI
        if (currentView == LibraryView.history) _buildSearchAndFilterBar(),
        Expanded(
          child: flatItems.isEmpty
              ? Center(
                  child: Text(
                    searchQuery.isNotEmpty || _selectedProductIds.isNotEmpty
                        ? '沒有符合條件的內容'
                        : showToLearn
                            ? '目前沒有待學習的內容'
                            : '目前沒有已學習的內容',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 16,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: flatItems.length,
                  itemBuilder: (context, index) {
        final item = flatItems[index];
        switch (item.type) {
          case _HistoryItemType.productHeader:
            return _buildProductGroup(
              context,
              item.productId!,
              item.toLearnCount!,
              item.learnedCount!,
              groupedByProduct[item.productId!]!,
              contentItemsMap,
              productsMap,
              showToLearn,
              searchQuery,
            );
          case _HistoryItemType.content:
          case _HistoryItemType.sectionHeader:
          case _HistoryItemType.spacer:
            return const SizedBox.shrink(); // 不再使用，但保留以兼容舊代碼
        }
                  },
                ),
        ),
      ],
    );
  }

  // Tab Chip 組件
  Widget _buildTabChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
            ? color.withValues(alpha: 0.2) 
            : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 階段 4：搜尋/篩選工具列
  Widget _buildSearchAndFilterBar() {
    final savedAsync = ref.watch(savedItemsProvider);
    final productsAsync = ref.watch(productsMapProvider);

    return productsAsync.when(
      data: (productsMap) {
        return savedAsync.when(
          data: (savedMap) {
            // 從 savedMap 推導產品列表（需要載入 ContentItem）
            // 注意：完整實作需要載入所有 ContentItem 才能知道有哪些產品
            // 這裡先顯示搜尋框，產品篩選功能可後續擴展
            return Container(
              padding: const EdgeInsets.all(12),
              color: Colors.transparent,
              child: Column(
                children: [
                  // 搜尋框
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜尋內容標題或產品名稱...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  // Tab 切換器
                  Row(
                    children: [
                      _buildTabChip(
                        label: '待學習',
                        icon: Icons.schedule,
                        color: Colors.orange,
                        isSelected: _selectedHistoryTab == 0,
                        onTap: () => setState(() => _selectedHistoryTab = 0),
                      ),
                      const SizedBox(width: 8),
                      _buildTabChip(
                        label: '已學習',
                        icon: Icons.check_circle,
                        color: Colors.green,
                        isSelected: _selectedHistoryTab == 1,
                        onTap: () => setState(() => _selectedHistoryTab = 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 產品篩選 Chip（簡化版：顯示所有產品）
                  // 注意：完整實作需要載入所有 ContentItem 才能知道有哪些產品
                  // 這裡先顯示一個提示
                  if (_selectedProductIds.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: [
                        ..._selectedProductIds.map((productId) {
                          final product = productsMap[productId];
                          return Chip(
                            label: Text(product?.title ?? productId),
                            onDeleted: () {
                              setState(() {
                                _selectedProductIds.remove(productId);
                              });
                            },
                          );
                        }),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedProductIds.clear();
                            });
                          },
                          child: const Text('清除篩選'),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ✅ 階段 2：產品分組卡片（ExpansionTile）
  Widget _buildProductGroup(
    BuildContext context,
    String productId,
    int toLearnCount,
    int learnedCount,
    Map<String, List<String>> group,
    Map<String, ContentItem> contentItemsMap,
    Map<String, Product> productsMap,
    bool showToLearn,
    String searchQuery,
  ) {
    final product = productsMap[productId];
    final productTitle = product?.title ?? '未知產品';
    
    // 根據 showToLearn 過濾內容
    final filteredToLearn = showToLearn
        ? group['toLearn']!
            .where((contentId) {
              if (searchQuery.isEmpty) return true;
              final contentItem = contentItemsMap[contentId];
              if (contentItem == null) return false;
              return _matchesSearch(searchQuery, contentItem, product);
            })
            .toList()
        : <String>[];
    
    final filteredLearned = !showToLearn
        ? group['learned']!
            .where((contentId) {
              if (searchQuery.isEmpty) return true;
              final contentItem = contentItemsMap[contentId];
              if (contentItem == null) return false;
              return _matchesSearch(searchQuery, contentItem, product);
            })
            .toList()
        : <String>[];
    
    // 排序內容：依 seq
    filteredToLearn.sort((a, b) {
      final seqA = contentItemsMap[a]?.seq ?? 0;
      final seqB = contentItemsMap[b]?.seq ?? 0;
      return seqA.compareTo(seqB);
    });
    filteredLearned.sort((a, b) {
      final seqA = contentItemsMap[a]?.seq ?? 0;
      final seqB = contentItemsMap[b]?.seq ?? 0;
      return seqA.compareTo(seqB);
    });
    
    final displayCount = showToLearn ? filteredToLearn.length : filteredLearned.length;
    final subtitle = showToLearn
        ? '待學習: $displayCount'
        : '已學習: $displayCount';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BubbleCard(
        child: ExpansionTile(
          title: Text(
            productTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            '共 $displayCount 則 ($subtitle)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          children: [
            // 根據 showToLearn 顯示對應的內容
            if (showToLearn && filteredToLearn.isNotEmpty)
              ...filteredToLearn.map((contentId) {
                final contentItem = contentItemsMap[contentId];
                if (contentItem == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: _buildHistoryCard(
                    context,
                    contentId,
                    false,
                    productsMap,
                    contentItem,
                  ),
                );
              })
            else if (!showToLearn && filteredLearned.isNotEmpty)
              ...filteredLearned.map((contentId) {
                final contentItem = contentItemsMap[contentId];
                if (contentItem == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: _buildHistoryCard(
                    context,
                    contentId,
                    true,
                    productsMap,
                    contentItem,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    String contentItemId,
    bool isLearned,
    Map<String, Product> productsMap,
    ContentItem? contentItem, // 可選，如果已載入則直接使用
  ) {
    // 如果已提供 contentItem，直接使用；否則從 provider 載入
    if (contentItem != null) {
      return _buildHistoryCardContent(
        context,
        contentItemId,
        isLearned,
        productsMap,
        contentItem,
      );
    }

    final contentAsync = ref.watch(contentItemProvider(contentItemId));

    return contentAsync.when(
      data: (item) => _buildHistoryCardContent(
        context,
        contentItemId,
        isLearned,
        productsMap,
        item,
      ),
      loading: () => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: BubbleCard(
          child: SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: BubbleCard(
          child: Text('載入錯誤: $e',
              style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  Widget _buildHistoryCardContent(
    BuildContext context,
    String contentItemId,
    bool isLearned,
    Map<String, Product> productsMap,
    ContentItem contentItem,
  ) {
    final product = productsMap[contentItem.productId];
    final productTitle = product?.title ?? '未知產品';
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        // ✅ 步驟 1：背景色區分狀態
        decoration: BoxDecoration(
          color: isLearned
              ? Colors.green.withValues(alpha: 0.1) // 已學習：淺綠色背景
              : Colors.orange.withValues(alpha: 0.1), // 待學習：淺橙色背景
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            BubbleCard(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DetailPage(contentItemId: contentItemId),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 產品名稱（上方，更大更突出）
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 16,
                        color: tokens.textPrimary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          productTitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: tokens.textPrimary,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 內容標題（下方，較小，使用 textSecondary 確保在淺色/深色主題都可見）
                  // ✅ 步驟 2：內容標題前加圖示
                  Row(
                    children: [
                      Icon(
                        isLearned
                            ? Icons.check_circle
                            : Icons.schedule, // 待學習=時鐘圖示，已學習=勾選圖示
                        size: 16,
                        color: isLearned
                            ? Colors.green
                            : Colors.orange, // 待學習=橙色，已學習=綠色
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Day ${contentItem.seq} · ${contentItem.anchorGroup}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ✅ 步驟 3：按鈕改為 Chip，放在內容標題下方
                  Align(
                    alignment: Alignment.centerRight,
                    child: ActionChip(
                      avatar: Icon(
                        isLearned ? Icons.undo : Icons.check_circle,
                        size: 16,
                        color: isLearned
                            ? tokens.textSecondary
                            : Colors.green,
                      ),
                      label: Text(
                        isLearned ? '標記待學習' : '標記已學習',
                        style: TextStyle(
                          fontSize: 12,
                          color: isLearned
                              ? tokens.textSecondary
                              : Colors.green,
                        ),
                      ),
                      onPressed: () async {
                        final uid = ref.read(uidProvider);
                        final repo = ref.read(libraryRepoProvider);
                        await repo.setSavedItem(
                          uid,
                          contentItemId,
                          {'learned': !isLearned},
                        );
                        ref.invalidate(savedItemsProvider);
                        _triggerReschedule();
                      },
                      backgroundColor: isLearned
                          ? null // 已學習：Outlined 樣式
                          : Colors.green.withValues(alpha: 0.2), // 待學習：綠色背景
                      side: isLearned
                          ? BorderSide(color: tokens.textSecondary)
                          : null,
                    ),
                  ),
                  if (contentItem.content.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      contentItem.content.length > 100
                          ? '${contentItem.content.substring(0, 100)}...'
                          : contentItem.content,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // ✅ 步驟 1：Badge（右上角）
            Positioned(
              top: 8,
              right: 8,
              child: Tooltip(
                message: isLearned
                    ? '已學習：不會被優先選中推播，只有在沒有待學習內容時才會被選中'
                    : '待學習：會被優先選中進行推播排程',
                waitDuration: const Duration(milliseconds: 500),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLearned
                        ? Colors.green.withValues(alpha: 0.2) // 已學習：綠色
                        : Colors.orange.withValues(alpha: 0.2), // 待學習：橙色
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLearned ? Colors.green : Colors.orange,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLearned ? Icons.check_circle : Icons.schedule,
                        size: 12,
                        color: isLearned ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isLearned ? '已學習' : '待學習',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isLearned ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ✅ 階段 4：搜尋/篩選邏輯
  bool _matchesSearch(String? query, ContentItem contentItem, Product? product) {
    if (query == null || query.isEmpty) return true;
    final lowerQuery = query.toLowerCase();
    return contentItem.anchorGroup.toLowerCase().contains(lowerQuery) ||
        contentItem.anchor.toLowerCase().contains(lowerQuery) ||
        (product?.title.toLowerCase().contains(lowerQuery) ?? false);
  }

  bool _matchesFilter(String productId) {
    if (_selectedProductIds.isEmpty) return true;
    return _selectedProductIds.contains(productId);
  }

  // ✅ 階段 10：觸發重排（帶防抖，500ms 內僅重排一次）
  void _triggerReschedule() {
    final now = DateTime.now();
    if (_lastRescheduleTime != null &&
        now.difference(_lastRescheduleTime!).inMilliseconds < 500) {
      return; // 防抖：500ms 內不重複觸發
    }
    _lastRescheduleTime = now;
    
    // 異步觸發重排，不阻塞 UI
    Future.microtask(() async {
      try {
        await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
      } catch (e) {
        debugPrint('重排推播失敗: $e');
      }
    });
  }

  Widget _buildFavoriteSentencesTab(BuildContext context) {
    // 檢查是否登入
    String? uid;
    try {
      uid = ref.read(uidProvider);
    } catch (_) {
      return const Center(child: Text('請先登入以使用此功能'));
    }

    final productsAsync = ref.watch(productsMapProvider);

    return productsAsync.when(
      data: (productsMap) {
        return FutureBuilder<List<FavoriteSentence>>(
          future: FavoriteSentencesStore.loadAll(uid!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('載入錯誤: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)),
              );
            }

            final sentences = snapshot.data ?? [];

            if (sentences.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.format_quote,
                        size: 64, color: Colors.white.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      '目前沒有收藏的今日一句',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '在內容詳情頁點擊 ⭐ 按鈕來收藏',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: sentences.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final sentence = sentences[index];
                final tokens = context.tokens;

                // 格式化收藏日期
                String formatDate(DateTime date) {
                  final now = DateTime.now();
                  final diff = now.difference(date);
                  if (diff.inDays == 0) {
                    return '今天';
                  } else if (diff.inDays == 1) {
                    return '昨天';
                  } else if (diff.inDays < 7) {
                    return '${diff.inDays} 天前';
                  } else {
                    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
                  }
                }

                return BubbleCard(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            DetailPage(contentItemId: sentence.contentItemId),
                      ),
                    );
                  },
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 產品名稱（標題）
                          Row(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 16,
                                color: tokens.textPrimary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  sentence.productName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: tokens.textPrimary,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // anchor group（副標題）
                          Row(
                            children: [
                              Icon(
                                Icons.label_outline,
                                size: 14,
                                color: tokens.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  sentence.anchorGroup,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // anchor（小字）
                          Text(
                            sentence.anchor,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // content（「今日一句」內容，主要顯示）
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Text(
                              sentence.content,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 收藏日期（右下角）
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              formatDate(sentence.favoritedAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // 刪除按鈕（右上角）
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: Colors.white.withValues(alpha: 0.6),
                          onPressed: () async {
                            if (uid == null) return;
                            await FavoriteSentencesStore.remove(
                                uid, sentence.contentItemId);
                            // 刷新列表
                            setState(() {});
                          },
                          tooltip: '取消收藏',
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('products error: $e')),
    );
  }
}

// ✅ 階段 1-3：學習歷史列表項目的數據結構
enum _HistoryItemType { sectionHeader, productHeader, content, spacer }

class _HistoryListItem {
  final _HistoryItemType type;
  final String? title;
  final String? productId;
  final String? contentId;
  final bool? isLearned;
  final int? toLearnCount;
  final int? learnedCount;

  _HistoryListItem._({
    required this.type,
    this.title,
    this.productId,
    this.contentId,
    this.isLearned,
    this.toLearnCount,
    this.learnedCount,
  });

  factory _HistoryListItem.sectionHeader(String title) =>
      _HistoryListItem._(type: _HistoryItemType.sectionHeader, title: title);

  factory _HistoryListItem.productHeader(
    String productId,
    int toLearnCount,
    int learnedCount,
  ) =>
      _HistoryListItem._(
        type: _HistoryItemType.productHeader,
        productId: productId,
        toLearnCount: toLearnCount,
        learnedCount: learnedCount,
      );

  factory _HistoryListItem.content(String contentId, bool isLearned) =>
      _HistoryListItem._(
        type: _HistoryItemType.content,
        contentId: contentId,
        isLearned: isLearned,
      );

  factory _HistoryListItem.spacer() =>
      _HistoryListItem._(type: _HistoryItemType.spacer);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
