import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifications/push_inbox_provider.dart';
import '../notifications/notification_inbox_store.dart';
import '../bubble_library/providers/providers.dart';
import '../bubble_library/ui/product_library_page.dart';

class PushInboxPage extends ConsumerWidget {
  const PushInboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(missedInboxProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('推播收件匣'),
        actions: [
          IconButton(
            tooltip: '清空',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              String uid;
              try {
                uid = ref.read(uidProvider);
              } catch (_) {
                return;
              }
              await NotificationInboxStore.clearAll(uid);
              ref.invalidate(missedInboxProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已清空收件匣')),
                );
              }
            },
          ),
        ],
      ),
      body: async.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('目前沒有錯過的推播'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final it = items[i];
              final dt = DateTime.fromMillisecondsSinceEpoch(it.whenMs);
              final timeText =
                  '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(timeText,
                          style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.55),
                              fontSize: 12)),
                      const SizedBox(height: 10),
                      Text(
                        it.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.75)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                // 補看：先導到商品內容頁（若你之後有 contentItem viewer，再精準導到那張）
                                await NotificationInboxStore.markOpened(
                                  uid: ref.read(uidProvider),
                                  productId: it.productId,
                                  contentItemId: it.contentItemId,
                                );
                                ref.invalidate(missedInboxProvider);

                                // ignore: use_build_context_synchronously
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => ProductLibraryPage(
                                    productId: it.productId,
                                    isWishlistPreview: false,
                                    initialContentItemId: it.contentItemId, // ✅ 精準跳轉
                                  ),
                                ));
                              },
                              child: const Text('補看'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: () async {
                              await NotificationInboxStore.dismiss(
                                uid: ref.read(uidProvider),
                                productId: it.productId,
                                contentItemId: it.contentItemId,
                              );
                              ref.invalidate(missedInboxProvider);
                            },
                            child: const Text('已讀'),
                          ),
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
}
