import 'package:flutter/material.dart';
import '../../app_card.dart';
import '../../../theme/app_tokens.dart';

class LibraryRichCard extends StatelessWidget {
  final String title;
  final String subtitle; // 例如 topicId · level
  final String? coverImageUrl;

  // 「三個資訊」先用 placeholder，之後再接推播排程 / 本週完成度
  final String nextPushText; // e.g. 每週一三五 08:30 / 下一則 10:30
  final String weeklyProgress; // e.g. 本週完成度 3/7
  final String latestTitle; // e.g. 最近：黑洞是什麼？

  // 右上角操作（⋯ 選單）
  final Widget? headerTrailing;

  final VoidCallback? onLearnNow;
  final VoidCallback? onMakeUpToday;
  final VoidCallback? onPreview3Days;
  final VoidCallback? onTap;

  const LibraryRichCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.coverImageUrl,
    required this.nextPushText,
    required this.weeklyProgress,
    required this.latestTitle,
    this.headerTrailing,
    this.onLearnNow,
    this.onMakeUpToday,
    this.onPreview3Days,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面（有就顯示）
          if (coverImageUrl != null && coverImageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: Image.network(
                coverImageUrl!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: tokens.chipBg,
                  alignment: Alignment.center,
                  child: Icon(Icons.image_not_supported,
                      color: tokens.textSecondary),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: tokens.textPrimary),
                      ),
                    ),
                    if (headerTrailing != null) ...[
                      const SizedBox(width: 8),
                      headerTrailing!,
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: tokens.textSecondary)),
                const SizedBox(height: 10),

                // 三個資訊（密度但不亂：一行一個）
                _InfoRow(icon: Icons.schedule, text: nextPushText),
                const SizedBox(height: 6),
                _InfoRow(
                    icon: Icons.check_circle_outline, text: weeklyProgress),
                const SizedBox(height: 6),
                _InfoRow(icon: Icons.notes, text: latestTitle),

              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        Icon(icon, size: 18, color: tokens.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.textSecondary),
          ),
        ),
      ],
    );
  }
}
