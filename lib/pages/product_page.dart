import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/v2_providers.dart';
import '../bubble_library/providers/providers.dart';
import '../ui/glass.dart';
import '../theme/app_tokens.dart';
import '../widgets/rich_sections/user_learning_store.dart';
import '../notifications/coming_soon_remind_store.dart';
import '../bubble_library/notifications/notification_service.dart';
import '../widgets/unlock_feature_bar.dart';

class ProductPage extends ConsumerStatefulWidget {
  final String productId;
  const ProductPage({super.key, required this.productId});

  @override
  ConsumerState<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends ConsumerState<ProductPage> {
  @override
  void initState() {
    super.initState();
    // 保底記錄：進入產品頁就記一次學習
    unawaited(UserLearningStore().markGlobalLearnedToday());
  }

  @override
  Widget build(BuildContext context) {
    final prod = ref.watch(productProvider(widget.productId));
    final previews = ref.watch(previewItemsProvider(widget.productId));
    final comingSoonSet = ref.watch(comingSoonIdsProvider);
    final wishAsync = ref.watch(wishlistProvider);
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        title: const Text('產品'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: prod.when(
        data: (p) {
          if (p == null) return const Center(child: Text('商品不存在或未上架'));
          final now = DateTime.now();
          final releaseAt = p.releaseAt;
          final isComingSoon = comingSoonSet.contains(widget.productId) ||
              (releaseAt != null && releaseAt.isAfter(now));
          final specs = [p.spec1Label, p.spec2Label, p.spec3Label, p.spec4Label]
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassCard(
                radius: 26,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 封面圖片
                    if (p.coverImageUrl != null && p.coverImageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(26)),
                        child: Image.network(
                          p.coverImageUrl!,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            height: 200,
                            color: tokens.chipBg,
                            child: Icon(Icons.image_not_supported,
                                size: 48, color: tokens.textSecondary),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.title,
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: tokens.textPrimary)),
                          const SizedBox(height: 6),
                          Text('${p.topicId} · ${p.level}',
                              style: TextStyle(color: tokens.textSecondary)),
                          if (isComingSoon) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: Colors.white.withValues(alpha: 0.10),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.14)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.lock_clock, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    '即將上架：目前不可購買',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          if ((p.levelGoal ?? '').isNotEmpty)
                            Text(p.levelGoal!,
                                style: TextStyle(color: tokens.textPrimary)),
                          const SizedBox(height: 6),
                          if ((p.levelBenefit ?? '').isNotEmpty)
                            Text(p.levelBenefit!,
                                style: TextStyle(color: tokens.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: specs
                    .map((s) => GlassCard(
                          radius: 999,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Text(s),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              Text('│ 試讀卡片',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: tokens.textPrimary)),
              const SizedBox(height: 10),
              previews.when(
                data: (items) => SizedBox(
                  height: 160,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final it = items[i];
                      return SizedBox(
                        width: 280,
                        child: GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(it.anchor,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: tokens.textPrimary)),
                              const SizedBox(height: 6),
                              Text(it.content,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      TextStyle(color: tokens.textSecondary)),
                              const Spacer(),
                              GlassCard(
                                radius: 999,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                child: Text('${it.intent} · d${it.difficulty}'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                loading: () => const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator())),
                error: (_, __) => const SizedBox(height: 160),
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
                child: UnlockProductBar(
                  productId: widget.productId,
                  priceText: r'NT$79',
                  onUnlocked: () async {
                    // ✅ 購買成功後：將產品加入已購買清單
                    String? uid;
                    try {
                      uid = ref.read(uidProvider);
                    } catch (_) {
                      uid = null;
                    }
                    if (uid != null) {
                      final repo = ref.read(libraryRepoProvider);
                      await repo.ensureLibraryProductExists(
                        uid: uid,
                        productId: widget.productId,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已解鎖，可啟用橫幅推播')),
                        );
                      }
                    }
                  },
                ),
              ),
              if (isComingSoon) ...[
                const SizedBox(height: 12),
                wishAsync.when(
                  data: (wish) {
                    String? uid;
                    try {
                      uid = ref.read(uidProvider);
                    } catch (_) {
                      uid = null;
                    }

                    final isWish = wish.any((w) => w.productId == widget.productId);

                    return Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(isWish ? Icons.favorite : Icons.favorite_border),
                            label: Text(isWish ? '已加入願望清單' : '加入願望清單'),
                            onPressed: (uid == null)
                                ? null
                                : () async {
                                    final repo = ref.read(libraryRepoProvider);
                                    if (isWish) {
                                      await repo.removeWishlist(uid!, widget.productId);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('已從願望清單移除')),
                                        );
                                      }
                                    } else {
                                      await repo.addWishlist(uid!, widget.productId);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('已加入願望清單')),
                                        );
                                      }
                                    }
                                  },
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const SizedBox(
                    height: 44,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('wishlist error: $e'),
                ),
                const SizedBox(height: 10),

                // ✅ 上架提醒
                FutureBuilder<Map<String, int>>(
                  future: (() async {
                    String? uid;
                    try {
                      uid = ref.read(uidProvider);
                    } catch (_) {
                      uid = null;
                    }
                    if (uid == null) return <String, int>{};
                    return ComingSoonRemindStore.load(uid);
                  })(),
                  builder: (context, snap) {
                    String? uid;
                    try {
                      uid = ref.read(uidProvider);
                    } catch (_) {
                      uid = null;
                    }

                    final map = snap.data ?? <String, int>{};
                    final hasRemind = uid != null && map.containsKey(widget.productId);

                    final notifId = widget.productId.hashCode & 0x7fffffff;

                    return OutlinedButton.icon(
                      icon: Icon(hasRemind
                          ? Icons.notifications_active
                          : Icons.notifications_active_outlined),
                      label: Text(hasRemind ? '已設定提醒（點一下取消）' : '上架時提醒我'),
                      onPressed: (uid == null)
                          ? null
                          : () async {
                              final ns = NotificationService();

                              if (hasRemind) {
                                await ComingSoonRemindStore.remove(
                                    uid: uid!, productId: widget.productId);
                                await ns.cancel(notifId);

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('已取消上架提醒')),
                                  );
                                }
                                // 讓 FutureBuilder 重新讀
                                if (context.mounted) {
                                  (context as Element).markNeedsBuild();
                                }
                                return;
                              }

                              // ✅ 有上架時間就用上架當天 09:00；沒有就退回明天 09:00（示意）
                              final now = DateTime.now();
                              final releaseAt = p.releaseAt;
                              final remindAt = (releaseAt != null)
                                  ? DateTime(releaseAt.year, releaseAt.month, releaseAt.day, 9)
                                  : DateTime(now.year, now.month, now.day, 9)
                                      .add(const Duration(days: 1));

                              await ComingSoonRemindStore.set(
                                uid: uid!,
                                productId: widget.productId,
                                remindAtMs: remindAt.millisecondsSinceEpoch,
                              );

                              await ns.schedule(
                                id: notifId,
                                when: remindAt,
                                title: '泡泡上架提醒',
                                body: '「${p.title}」已準備上架，回來看看吧！',
                                payload: {
                                  'type': 'coming_soon_remind',
                                  'productId': widget.productId,
                                },
                              );

                              if (context.mounted) {
                                final dateText = (releaseAt != null)
                                    ? '${remindAt.year}-${remindAt.month.toString().padLeft(2, '0')}-${remindAt.day.toString().padLeft(2, '0')} ${remindAt.hour.toString().padLeft(2, '0')}:${remindAt.minute.toString().padLeft(2, '0')}'
                                    : '明天 ${remindAt.hour.toString().padLeft(2, '0')}:${remindAt.minute.toString().padLeft(2, '0')}（示意）';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('已設定提醒：$dateText'),
                                  ),
                                );
                              }

                              // 讓 FutureBuilder 重新讀
                              if (context.mounted) {
                                (context as Element).markNeedsBuild();
                              }
                            },
                    );
                  },
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('讀取失敗:',
                      style: TextStyle(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '$err',
                    style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
