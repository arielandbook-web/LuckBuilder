import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../models/product.dart';
import '../models/user_library.dart';
import '../models/push_config.dart';
import '../notifications/push_orchestrator.dart';
import 'product_library_page.dart';
import 'push_center_page.dart';
import 'push_product_config_page.dart';
import 'widgets/bubble_card.dart';

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
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PushCenterPage())),
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
                        final visibleLib = lib.where((e) => !e.isHidden && productsMap.containsKey(e.productId)).toList();
                        final visibleWish = wish.where((e) => productsMap.containsKey(e.productId)).toList();

                        if (tab == LibraryTab.purchased) {
                          if (visibleLib.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white.withOpacity(0.5)),
                                  const SizedBox(height: 16),
                                  Text(
                                    '目前沒有已購買的商品',
                                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
                                  ),
                                  if (kDebugMode) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      '點擊右上角的 🌾 按鈕來建立測試資料',
                                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
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
                            itemBuilder: (_, i) {
                              final lp = visibleLib[i];
                              final title = productsMap[lp.productId]!.title;
                              return BubbleCard(
                                onTap: () async {
                                  await ref.read(libraryRepoProvider).touchLastOpened(ref.read(uidProvider), lp.productId);
                                  // ignore: use_build_context_synchronously
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => ProductLibraryPage(productId: lp.productId, isWishlistPreview: false),
                                  ));
                                },
                                child: _purchasedCard(context, lp, title),
                              );
                            },
                          );
                        }

                        if (tab == LibraryTab.wishlist) {
                          if (visibleWish.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.favorite_border, size: 64, color: Colors.white.withOpacity(0.5)),
                                  const SizedBox(height: 16),
                                  Text(
                                    '目前沒有願望清單',
                                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
                                  ),
                                  if (kDebugMode) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      '點擊右上角的 🌾 按鈕來建立測試資料',
                                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
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
                            itemBuilder: (_, i) {
                              final w = visibleWish[i];
                              final title = productsMap[w.productId]!.title;
                              return BubbleCard(
                                onTap: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => ProductLibraryPage(productId: w.productId, isWishlistPreview: true),
                                  ));
                                },
                                child: _wishlistCard(context, w, title),
                              );
                            },
                          );
                        }

                        // Favorites
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
                                Icon(Icons.star_border, size: 64, color: Colors.white.withOpacity(0.5)),
                                const SizedBox(height: 16),
                                Text(
                                  '目前沒有最愛',
                                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '點擊商品旁的 ⭐ 按鈕來加入最愛',
                                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: favList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final pid = favList[i];
                            final title = productsMap[pid]!.title;
                            final lp = visibleLib.where((e) => e.productId == pid).firstOrNull;
                            final isPurchased = lp != null;

                            return BubbleCard(
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => ProductLibraryPage(productId: pid, isWishlistPreview: !isPurchased),
                                ));
                              },
                              child: Row(
                                children: [
                                  const Icon(Icons.star, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                                  Text(isPurchased ? '已購買' : '未購買', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('wishlist error: $e')),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
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

  Widget _purchasedCard(BuildContext context, UserLibraryProduct lp, String title) {
    final uid = ref.read(uidProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.bubble_chart_outlined, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                  IconButton(
                    icon: Icon(lp.isFavorite ? Icons.star : Icons.star_border),
                    onPressed: () async {
                      await ref.read(libraryRepoProvider).setProductFavorite(uid, lp.productId, !lp.isFavorite);
                    },
                  ),
                  IconButton(
                    icon: Icon(lp.pushEnabled ? Icons.notifications_active : Icons.notifications_off_outlined),
                    onPressed: () async {
                      await ref.read(libraryRepoProvider).setPushEnabled(uid, lp.productId, !lp.pushEnabled);
                      await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _chip(lp.pushEnabled ? '推播中' : '未推播'),
                  _chip('Day ${lp.progress.nextSeq}/365'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '購買：${lp.purchasedAt.toLocal().toString().split(".").first}',
                style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await ref.read(libraryRepoProvider).hideProduct(uid, lp.productId, true);
                      await PushOrchestrator.rescheduleNextDays(ref: ref, days: 3);
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('刪除'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PushProductConfigPage(productId: lp.productId)),
                    ),
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('推播設定'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _wishlistCard(BuildContext context, WishlistItem w, String title) {
    final uid = ref.read(uidProvider);

    return Row(
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
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                  IconButton(
                    icon: Icon(w.isFavorite ? Icons.star : Icons.star_border),
                    onPressed: () async {
                      await ref.read(libraryRepoProvider).setProductFavorite(uid, w.productId, !w.isFavorite);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [_chip('未購買'), _chip('試讀可用')]),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      // TODO: 在此串接 IAP / RevenueCat 購買流程
                      // 購買成功後，呼叫以下程式碼將商品加入泡泡庫：
                      final purchasedProductId = w.productId; // 實際應從 IAP 回傳取得
                      await ref.read(libraryRepoProvider).ensureLibraryProductExists(
                        uid: ref.read(uidProvider),
                        productId: purchasedProductId,
                        purchasedAt: DateTime.now(),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('購買成功！商品已加入泡泡庫')),
                        );
                      }
                    },
                    child: const Text('立即購買'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () async {
                      await ref.read(libraryRepoProvider).removeWishlist(uid, w.productId);
                    },
                    child: const Text('移除收藏'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Text(text, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
      );

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
          const SnackBar(content: Text('Debug 資料已建立：1-2 個已購買商品、1 個願望清單，其中一個已啟用推播')),
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
