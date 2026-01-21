import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collections/collections_controller.dart';
import '../providers/providers.dart';
import '../models/product.dart';
import '../models/push_config.dart';
import '../notifications/push_orchestrator.dart';
import '../notifications/scheduled_push_cache.dart';
import 'collections_manage_page.dart';
import 'product_library_page.dart';
import 'push_center_page.dart';
import 'push_product_config_page.dart';
import 'widgets/bubble_card.dart';
import '../../widgets/rich_sections/sections/library_rich_card.dart';
import '../../widgets/rich_sections/user_learning_store.dart';
import '../../../theme/app_tokens.dart';

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
  String? selectedCollectionId;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsMapProvider);

    // 檢查是否登入，未登入時顯示提示
    String? uid;
    try {
      uid = ref.read(uidProvider);
    } catch (_) {
      return Scaffold(
        appBar: AppBar(title: const Text('泡泡庫')),
        body: const Center(child: Text('請先登入以使用泡泡庫功能')),
      );
    }

    final libAsync = ref.watch(libraryProductsProvider);
    final wishAsync = ref.watch(wishlistProvider);
    final scheduledAsync = ref.watch(_scheduledCacheProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('泡泡庫'),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.agriculture),
              tooltip: 'Seed Debug Data',
              onPressed: () => _seedDebugData(context, uid!),
            ),
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
                      data: (wish) {
                        final visibleLib = lib
                            .where((e) =>
                                !e.isHidden &&
                                productsMap.containsKey(e.productId))
                            .toList();
                        final visibleWish = wish
                            .where((e) => productsMap.containsKey(e.productId))
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
                              context, visibleWish, productsMap);
                        }

                        // Favorites
                        return _buildFavoritesTab(
                            context, visibleLib, visibleWish, productsMap);
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
            if (kDebugMode) ...[
              const SizedBox(height: 8),
              Text(
                '點擊右上角的 🌾 按鈕來建立測試資料',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
              ),
            ],
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

  Widget _buildWishlistTab(BuildContext context, List<dynamic> visibleWish,
      Map<String, Product> productsMap) {
    if (visibleWish.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border,
                size: 64, color: Colors.white.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              '目前沒有願望清單',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8), fontSize: 16),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 8),
              Text(
                '點擊右上角的 🌾 按鈕來建立測試資料',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
              ),
            ],
          ],
        ),
      );
    }
    visibleWish.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: visibleWish.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final w = visibleWish[i];
        final product = productsMap[w.productId]!;
        final uid2 = ref.read(uidProvider);
        final tokens = ctx.tokens;
        return LibraryRichCard(
          title: product.title,
          subtitle: '未購買 · 可試讀 ${product.trialLimit} 則',
          coverImageUrl: null,
          nextPushText: '試播：今晚 21:30（示意）',
          weeklyProgress: '相符標籤：AI · 宇宙（示意）',
          latestTitle: '免費預覽：第 1 則內容標題（示意）',
          headerTrailing: PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz, color: tokens.textSecondary),
            onSelected: (v) async {
              final repo = ref.read(libraryRepoProvider);
              if (v == 'fav') {
                await repo.setProductFavorite(uid2, w.productId, !w.isFavorite);
              } else if (v == 'remove') {
                await repo.removeWishlist(uid2, w.productId);
              } else if (v == 'buy') {
                await repo.ensureLibraryProductExists(
                  uid: uid2,
                  productId: w.productId,
                  purchasedAt: DateTime.now(),
                );
                await repo.removeWishlist(uid2, w.productId);
                await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('購買成功！商品已加入泡泡庫（示意）')));
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'fav',
                child: Row(
                  children: [
                    Icon(w.isFavorite ? Icons.star : Icons.star_border),
                    const SizedBox(width: 10),
                    Text(w.isFavorite ? '移除最愛' : '加入最愛'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'buy',
                child: Row(
                  children: [
                    Icon(Icons.shopping_bag_outlined),
                    SizedBox(width: 10),
                    Text('立即購買'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline),
                    SizedBox(width: 10),
                    Text('移除收藏'),
                  ],
                ),
              ),
            ],
          ),
          onLearnNow: () {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('預覽 1 則（示意）')));
          },
          onMakeUpToday: () {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('導向購買（示意）')));
          },
          onPreview3Days: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ProductLibraryPage(
                  productId: w.productId, isWishlistPreview: true),
            ));
          },
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ProductLibraryPage(
                  productId: w.productId, isWishlistPreview: true),
            ));
          },
        );
      },
    );
  }

  Widget _buildFavoritesTab(
    BuildContext context,
    List<dynamic> visibleLib,
    List<dynamic> visibleWish,
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
    final colsAsync = ref.watch(collectionsControllerProvider);

    Widget collectionsBar() {
      return colsAsync.when(
        data: (cols) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('收藏集',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const CollectionsManagePage()),
                    ),
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('管理'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _colChip(
                      label: '全部',
                      selected: selectedCollectionId == null,
                      onTap: () => setState(() => selectedCollectionId = null),
                    ),
                    const SizedBox(width: 8),
                    ...cols.map((c) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _colChip(
                            label: '${c.name} (${c.productIds.length})',
                            selected: selectedCollectionId == c.id,
                            onTap: () =>
                                setState(() => selectedCollectionId = c.id),
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      );
    }

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

    // 若選了收藏集，就只顯示該收藏集內的 fav
    final cols = colsAsync.value ?? [];
    final selected = selectedCollectionId == null
        ? null
        : cols.where((e) => e.id == selectedCollectionId).firstOrNull;

    final filteredFavList = selected == null
        ? favList
        : favList.where((pid) => selected.productIds.contains(pid)).toList();

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: filteredFavList.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        if (i == 0) return collectionsBar();

        final pid = filteredFavList[i - 1];
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
              IconButton(
                tooltip: '加入收藏集',
                icon: const Icon(Icons.playlist_add),
                onPressed: () => _openCollectionPicker(
                  context: context,
                  productId: pid,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _colChip(
      {required String label,
      required bool selected,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.08),
          border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.12)),
        ),
        child: Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 12,
                fontWeight: FontWeight.w800)),
      ),
    );
  }

  Future<void> _openCollectionPicker({
    required BuildContext context,
    required String productId,
  }) async {
    final ctrl = ref.read(collectionsControllerProvider.notifier);
    final cols = ref.read(collectionsControllerProvider).value ?? [];

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        final nameCtl = TextEditingController();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('加入/移出收藏集',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                if (cols.isEmpty)
                  const Text('尚無收藏集，先建立一個吧～')
                else
                  ...cols.map((c) {
                    final has = c.productIds.contains(productId);
                    return CheckboxListTile(
                      value: has,
                      onChanged: (_) async {
                        await ctrl.toggleProduct(
                            collectionId: c.id, productId: productId);
                        if (context.mounted) Navigator.pop(context);
                      },
                      title: Text(c.name),
                      subtitle: Text('包含 ${c.productIds.length} 個'),
                    );
                  }),
                const Divider(height: 20),
                TextField(
                  controller: nameCtl,
                  decoration: const InputDecoration(
                    labelText: '建立新收藏集',
                    hintText: '例如：睡前 10 分鐘',
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await ctrl.create(nameCtl.text);
                      final list =
                          ref.read(collectionsControllerProvider).value ?? [];
                      if (list.isNotEmpty) {
                        await ctrl.toggleProduct(
                            collectionId: list.first.id, productId: productId);
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('建立並加入'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _seedDebugData(BuildContext context, String uid) async {
    final productsAsync = ref.read(productsMapProvider);
    final productsMap = productsAsync.when(
      data: (map) => map,
      loading: () => <String, Product>{},
      error: (_, __) => <String, Product>{},
    );

    if (productsMap.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('沒有可用的商品資料')),
        );
      }
      return;
    }

    final productIds = productsMap.keys.toList();
    if (productIds.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('沒有可用的商品')),
        );
      }
      return;
    }

    final repo = ref.read(libraryRepoProvider);
    final now = DateTime.now();

    try {
      // 建立 1-2 個 library_products
      final libraryProductIds = productIds.take(2).toList();
      for (final productId in libraryProductIds) {
        await repo.ensureLibraryProductExists(
          uid: uid,
          productId: productId,
          purchasedAt: now,
        );
      }

      // 將第一個商品設定為 pushEnabled=true + 預設 pushConfig
      if (libraryProductIds.isNotEmpty) {
        final firstProductId = libraryProductIds[0];
        await repo.setPushEnabled(uid, firstProductId, true);
        final defaultConfig = PushConfig.defaults();
        await repo.setPushConfig(uid, firstProductId, defaultConfig.toMap());
      }

      // 建立 1 個 wishlist（選擇一個不在 library 中的商品）
      final wishlistProductId = productIds.firstWhere(
        (id) => !libraryProductIds.contains(id),
        orElse: () => productIds[0],
      );
      await repo.addWishlist(uid, wishlistProductId);

      // 重排推播
      await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Debug 資料已建立：1-2 個已購買商品、1 個願望清單，其中一個已啟用推播')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('建立 Debug 資料時發生錯誤：$e')),
        );
      }
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
