import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../notifications/notification_inbox_store.dart';
import '../../../notifications/notification_inbox_provider.dart';
import '../product_library_page.dart';
import 'bubble_card.dart';
import '../../providers/providers.dart';
import '../../../theme/app_tokens.dart';

class PushInboxSection extends ConsumerWidget {
  const PushInboxSection({super.key});

  /// 處理點擊項目：markOpened → invalidate → navigate
  Future<void> _handleItemTap(
    BuildContext context,
    WidgetRef ref,
    String uid,
    String productId,
    String contentItemId,
  ) async {
    // 標記為已讀
    if (productId.isNotEmpty && contentItemId.isNotEmpty) {
      await NotificationInboxStore.markOpened(
        uid,
        productId: productId,
        contentItemId: contentItemId,
      );

      // 刷新 providers
      ref.invalidate(inboxItemsProvider);
      ref.invalidate(inboxUnreadCountProvider);
    }

    // 導航到產品頁
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductLibraryPage(
            productId: productId,
            isWishlistPreview: false,
            initialContentItemId: contentItemId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(inboxUnreadCountProvider);
    final inboxItemsAsync = ref.watch(inboxItemsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '推播收件匣',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 8),
            // 未讀數 badge
            unreadCountAsync.when(
              data: (count) {
                if (count == 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    count > 99 ? '99+' : count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 10),
        inboxItemsAsync.when(
          data: (items) {
            // 顯示前 5 筆最新（未讀優先）
            final unread = items
                .where((item) => item.status != InboxStatus.opened)
                .toList();
            final read = items
                .where((item) => item.status == InboxStatus.opened)
                .toList();
            final displayItems = [
              ...unread.take(3),
              ...read.take(5 - unread.length.clamp(0, 3)),
            ];

            if (displayItems.isEmpty) {
              return BubbleCard(
                child: Text(
                  '沒有錯過的推播 🎉',
                  style: TextStyle(
                    color: context.tokens.textSecondary,
                  ),
                ),
              );
            }

            return BubbleCard(
              child: Column(
                children: displayItems.map((item) {
                  final productId = item.productId;
                  final contentItemId = item.contentItemId;
                  final isRead = item.status == InboxStatus.opened;
                  final when = DateTime.fromMillisecondsSinceEpoch(item.whenMs);

                  return Opacity(
                    opacity: isRead ? 0.65 : 1.0,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          const Icon(Icons.inbox, size: 20),
                        ],
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: isRead
                              ? context.tokens.textSecondary
                              : context.tokens.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${_fmt(when)} · $productId',
                        style: TextStyle(
                          color: context.tokens.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          try {
                            final uid = ref.read(uidProvider);
                            await _handleItemTap(
                              context,
                              ref,
                              uid,
                              productId,
                              contentItemId,
                            );
                          } catch (_) {
                            // 未登入時不處理
                          }
                        },
                        child: const Text('補看'),
                      ),
                      onTap: () async {
                        try {
                          final uid = ref.read(uidProvider);
                          await _handleItemTap(
                            context,
                            ref,
                            uid,
                            productId,
                            contentItemId,
                          );
                        } catch (_) {
                          // 未登入時不處理
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => BubbleCard(
            child: Text(
              '載入收件匣時發生錯誤',
              style: TextStyle(
                color: context.tokens.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () {
                ref.invalidate(inboxItemsProvider);
                ref.invalidate(inboxUnreadCountProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('更新收件匣'),
            ),
          ],
        ),
      ],
    );
  }

  String _fmt(DateTime dt) {
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}
