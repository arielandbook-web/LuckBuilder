import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../models/content_item.dart';
import '../models/user_library.dart';
import 'detail_page.dart';
import 'widgets/bubble_card.dart';
import '../../../theme/app_tokens.dart';
import '../../widgets/rich_sections/user_learning_store.dart';

class ProductLibraryPage extends ConsumerStatefulWidget {
  final String productId;
  final bool isWishlistPreview;

  // ✅ 新增：指定要跳到哪一張 content
  final String? initialContentItemId;

  const ProductLibraryPage({
    super.key,
    required this.productId,
    required this.isWishlistPreview,
    this.initialContentItemId,
  });

  @override
  ConsumerState<ProductLibraryPage> createState() => _ProductLibraryPageState();
}

class _ProductLibraryPageState extends ConsumerState<ProductLibraryPage> {
  final Map<String, GlobalKey> _itemKeys = {};
  bool _didJump = false;
  int _jumpAttempts = 0;

  void _tryJumpToTarget() {
    final targetId = widget.initialContentItemId;
    if (targetId == null || targetId.isEmpty) return;
    if (_didJump) return;
    if (_jumpAttempts >= 8) return; // 避免無限嘗試

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _itemKeys[targetId];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: 0.15, // 讓目標卡片偏上，視覺更舒服
        );
        _didJump = true;
        return;
      }
      _jumpAttempts += 1;
      // 下一次 build 再試
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    // 保底記錄：進入內容頁就記一次學習
    unawaited(UserLearningStore().markLearnedTodayAndGlobal(widget.productId));
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsMapProvider);
    final contentsAsync = ref.watch(contentByProductProvider(widget.productId));
    final savedAsync = ref.watch(savedItemsProvider);
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        title: const Text('內容卡片'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: productsAsync.when(
        data: (productsMap) {
          final product = productsMap[widget.productId];
          if (product == null) {
            return const Center(child: Text('Product not found'));
          }

          return contentsAsync.when(
            data: (items) {
              final showItems = widget.isWishlistPreview
                  ? items.take(product.trialLimit).toList()
                  : items;

              return savedAsync.when(
                data: (savedMap) {
                  // ✅ 嘗試跳轉到目標 content
                  _tryJumpToTarget();

                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      BubbleCard(
                        child: Row(
                          children: [
                            const Icon(Icons.bubble_chart_outlined, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product.title,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      _chip(widget.isWishlistPreview
                                          ? '試讀模式'
                                          : '泡泡庫'),
                                      _chip('卡片 ${showItems.length}'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...showItems.map((it) {
                        final saved = savedMap[it.id];

                        // ✅ 每張卡都給一個 GlobalKey，讓 ensureVisible 找得到
                        final k = _itemKeys.putIfAbsent(it.id, () => GlobalKey());

                        final isTarget = (it.id == widget.initialContentItemId);

                        // 原本的卡片 widget
                        final original = Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: BubbleCard(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      DetailPage(contentItemId: it.id)),
                            ),
                            child: _contentCard(ref, it, saved),
                          ),
                        );

                        // 可選：目標卡片加一個淡淡外框，讓使用者知道「跳到這張」
                        return Container(
                          key: k, // ✅ GlobalKey 要掛在真正的 Element 上，ensureVisible 才抓得到 context
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: isTarget
                                  ? Border.all(
                                      width: 1.5,
                                      color: Colors.blue.withValues(alpha: 0.5),
                                    )
                                  : null,
                            ),
                            child: original,
                          ),
                        );
                      }),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('saved error: $e')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('content error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('products error: $e')),
      ),
    );
  }

  Widget _contentCard(WidgetRef ref, ContentItem it, SavedContent? saved) {
    // 檢查是否登入
    String? uid;
    try {
      uid = ref.read(uidProvider);
    } catch (_) {
      return const Center(child: Text('請先登入'));
    }

    final repo = ref.read(libraryRepoProvider);

    String ellipsize(String s, int max) =>
        s.length <= max ? s : '${s.substring(0, max)}…';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 標題和序號
        Row(
          children: [
            Expanded(
              child: Text(
                it.anchorGroup,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
            Builder(
              builder: (context) {
                final tokens = context.tokens;
                return Text(
                  'Day ${it.pushOrder}',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 內容預覽（增加字數限制，最多2行）
        Text(
          ellipsize(it.content, 100),
          style: const TextStyle(fontSize: 15, height: 1.4),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),
        // 操作按鈕（簡化為圖示按鈕）
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: Icon((saved?.learned ?? false)
                  ? Icons.check_circle
                  : Icons.check_circle_outline),
              onPressed: () => repo.setSavedItem(
                  uid!, it.id, {'learned': !(saved?.learned ?? false)}),
              tooltip: '我學會了',
            ),
            IconButton(
              icon: Icon(
                  (saved?.favorite ?? false) ? Icons.star : Icons.star_border),
              onPressed: () => repo.setSavedItem(
                  uid!, it.id, {'favorite': !(saved?.favorite ?? false)}),
              tooltip: '收藏',
            ),
            IconButton(
              icon: Icon((saved?.reviewLater ?? false)
                  ? Icons.schedule
                  : Icons.schedule_outlined),
              onPressed: () => repo.setSavedItem(
                  uid!, it.id, {'reviewLater': !(saved?.reviewLater ?? false)}),
              tooltip: '稍後',
            ),
          ],
        ),
      ],
    );
  }

  Widget _chip(String text) => Builder(
        builder: (context) {
          final tokens = context.tokens;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: tokens.chipGradient,
              color: tokens.chipGradient == null ? tokens.chipBg : null,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: tokens.cardBorder),
            ),
            child: Text(
              text,
              style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          );
        },
      );
}
