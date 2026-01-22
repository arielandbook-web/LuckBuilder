import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bubble_library/providers/providers.dart';
import '../bubble_library/ui/product_library_page.dart';
import '../widgets/app_card.dart';
import '../theme/app_tokens.dart';
import 'notification_inbox_provider.dart';
import 'notification_inbox_store.dart';

class NotificationInboxPage extends ConsumerWidget {
  final bool showMissedOnly; // 只顯示錯過的推播

  const NotificationInboxPage({
    super.key,
    this.showMissedOnly = false,
  });

  /// 處理點擊項目：markOpened → invalidate → navigate
  Future<void> _handleItemTap(
    BuildContext context,
    WidgetRef ref,
    String uid,
    InboxItem item,
  ) async {
    // 標記為已讀
    await NotificationInboxStore.markOpened(
      uid,
      productId: item.productId,
      contentItemId: item.contentItemId,
    );

    // 刷新 providers
    ref.invalidate(inboxItemsProvider);
    ref.invalidate(inboxUnreadCountProvider);

    // 導航到產品頁
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductLibraryPage(
            productId: item.productId,
            isWishlistPreview: false,
            initialContentItemId: item.contentItemId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String uid;
    try {
      uid = ref.read(uidProvider);
    } catch (_) {
      return const Scaffold(body: Center(child: Text('請先登入')));
    }

    final tokens = context.tokens;
    final asyncItems = ref.watch(inboxItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(showMissedOnly ? '錯過的推播' : '推播收件匣'),
        actions: [
          if (showMissedOnly)
            TextButton(
              onPressed: () async {
                await NotificationInboxStore.clearMissed(uid);
                ref.invalidate(inboxItemsProvider);
                ref.invalidate(inboxUnreadCountProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已清空錯過的推播')),
                  );
                }
              },
              child: const Text('清空錯過'),
            ),
          if (!showMissedOnly) ...[
            TextButton(
              onPressed: () async {
                await NotificationInboxStore.clearMissed(uid);
                ref.invalidate(inboxItemsProvider);
                ref.invalidate(inboxUnreadCountProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已清空錯過的推播')),
                  );
                }
              },
              child: const Text('清空錯過'),
            ),
            IconButton(
              tooltip: '全部清空',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await NotificationInboxStore.clearAll(uid);
                ref.invalidate(inboxItemsProvider);
                ref.invalidate(inboxUnreadCountProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已全部清空')),
                  );
                }
              },
            ),
          ],
        ],
      ),
      body: asyncItems.when(
        data: (items) {
          // 如果只顯示錯過的，進行過濾
          final displayItems = showMissedOnly
              ? items.where((e) => e.status == InboxStatus.missed).toList()
              : items;

          if (displayItems.isEmpty) {
            return Center(
              child: Text(
                showMissedOnly
                    ? '太棒了！最近沒有漏掉的推播'
                    : '目前收件匣是空的',
                style: TextStyle(color: tokens.textSecondary),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: displayItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final item = displayItems[i];
              final when = DateTime.fromMillisecondsSinceEpoch(item.whenMs);
              final isRead = item.status == InboxStatus.opened;

              return Opacity(
                opacity: isRead ? 0.65 : 1.0,
                child: AppCard(
                  onTap: () => _handleItemTap(context, ref, uid, item),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 未讀 dot（左側）
                      if (!isRead) ...[
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6, right: 12),
                          decoration: BoxDecoration(
                            color: tokens.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ] else
                        const SizedBox(width: 20), // 已讀時保留空間
                      // 內容
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 時間 + 狀態 badge
                            Row(
                              children: [
                                Text(
                                  _fmt(when),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isRead
                                        ? tokens.textSecondary
                                        : tokens.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: tokens.chipBg,
                                    border: Border.all(
                                      color: tokens.cardBorder,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    _getStatusBadge(item.status),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: tokens.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // 標題
                            Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isRead
                                    ? tokens.textSecondary
                                    : tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // 內容預覽
                            Text(
                              item.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: tokens.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'inbox error: $e',
            style: TextStyle(color: tokens.textSecondary),
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d  $hh:$mm';
  }

  String _getStatusBadge(InboxStatus status) {
    switch (status) {
      case InboxStatus.missed:
        return '錯過';
      case InboxStatus.opened:
        return '已開啟';
      case InboxStatus.scheduled:
        return '已排程';
      case InboxStatus.skipped:
        return '已跳過';
    }
  }
}
