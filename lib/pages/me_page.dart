import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_scaffold.dart';
import '../theme/app_tokens.dart';
import '../widgets/rich_sections/sections/me_dashboard_section.dart';
import '../widgets/rich_sections/sections/me_interest_tags_section.dart';
import '../widgets/rich_sections/sections/me_achievements_section.dart';

class MePage extends ConsumerWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final themeController = ref.watch(themeControllerProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '我的',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: tokens.textPrimary,
                ),
          ),
          const SizedBox(height: 16),

          // 學習儀表板
          const MeDashboardSection(),
          const SizedBox(height: 14),

          // 興趣標籤
          const MeInterestTagsSection(),
          const SizedBox(height: 14),

          // 里程碑/成就
          const MeAchievementsSection(),
          const SizedBox(height: 18),

          ListTile(
            leading: Icon(Icons.color_lens_outlined, color: tokens.primary),
            title: Text('切換主題', style: TextStyle(color: tokens.textPrimary)),
            subtitle: Text(
              themeController.id.name == 'darkNeon' ? '深色霓虹' : '純白薄荷',
              style: TextStyle(color: tokens.textSecondary),
            ),
            trailing: Switch(
              value: themeController.id.name == 'whiteMint',
              onChanged: (_) => themeController.toggle(),
            ),
            onTap: () => themeController.toggle(),
          ),
          const SizedBox(height: 16),
          Text(
            '訂閱狀態 / 收藏 / 設定（MVP 先占位）',
            style: TextStyle(color: tokens.textSecondary),
          ),
        ],
      ),
    );
  }
}
