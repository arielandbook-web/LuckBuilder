import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bubble_library/providers/providers.dart';
import '../bubble_library/ui/product_library_page.dart';
import 'notification_inbox_provider.dart';
import 'notification_inbox_store.dart';

class NotificationInboxPage extends ConsumerWidget {
  final bool showMissedOnly; // 只顯示錯過的推播

  const NotificationInboxPage({
    super.key,
    this.showMissedOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String uid;
    try {
      uid = ref.read(uidProvider);
    } catch (_) {
      return const Scaffold(body: Center(child: Text('請先登入')));
    }

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
          
          final missed = items.where((e) => e.status == InboxStatus.missed).toList();
          
          if (displayItems.isEmpty) {
            return Center(
              child: Text(showMissedOnly 
                  ? '太棒了！最近沒有漏掉的推播' 
                  : '目前收件匣是空的'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: displayItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final it = displayItems[i];
              final when = DateTime.fromMillisecondsSinceEpoch(it.whenMs);

              final badge = switch (it.status) {
                InboxStatus.missed => '錯過',
                InboxStatus.opened => '已開啟',
                InboxStatus.scheduled => '已排程',
                InboxStatus.skipped => '已跳過',
              };

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(_fmt(when),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 13)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Text(badge, style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(it.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(
                        it.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.visibility),
                            label: const Text('補看'),
                            onPressed: () async {
                              await NotificationInboxStore.markOpened(
                                uid,
                                productId: it.productId,
                                contentItemId: it.contentItemId,
                              );
                              ref.invalidate(inboxItemsProvider);

                              if (context.mounted) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ProductLibraryPage(
                                      productId: it.productId,
                                      isWishlistPreview: false,
                                      initialContentItemId: it.contentItemId,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 10),
                          if (it.status == InboxStatus.missed)
                            Text('錯過共 ${missed.length} 則',
                                style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('inbox error: $e')),
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
}
