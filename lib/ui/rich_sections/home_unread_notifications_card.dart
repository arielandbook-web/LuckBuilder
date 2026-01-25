import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/app_card.dart';
import '../../theme/app_tokens.dart';
import '../../../notifications/notification_inbox_provider.dart';
import '../../../notifications/notification_inbox_page.dart';

class HomeUnreadNotificationsCard extends ConsumerWidget {
  const HomeUnreadNotificationsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final unreadCountAsync = ref.watch(inboxUnreadCountProvider);

    return unreadCountAsync.when(
      data: (count) {
        // 沒有未讀通知時隱藏卡片
        if (count == 0) {
          return const SizedBox.shrink();
        }

        return AppCard(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationInboxPage(),
              ),
            );
          },
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 左側圖示
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_active,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // 中間文字
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '未讀通知',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      count == 1 ? '1 則未讀' : '$count 則未讀',
                      style: TextStyle(
                        fontSize: 13,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // 右側 badge 和箭頭
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: tokens.textSecondary,
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
  }
}
