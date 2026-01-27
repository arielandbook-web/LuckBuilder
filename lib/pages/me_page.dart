import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_scaffold.dart';
import '../theme/app_tokens.dart';
import '../widgets/rich_sections/sections/me_dashboard_section.dart';
import '../widgets/rich_sections/sections/me_interest_tags_section.dart';
import '../widgets/rich_sections/sections/me_achievements_section.dart';
import '../services/reset_service.dart';
import '../bubble_library/providers/providers.dart';

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
          const Divider(),
          ListTile(
            leading: Icon(Icons.restore_outlined, color: Colors.red),
            title: Text(
              '重置所有数据',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: Text(
              '清除所有学习进度、设置和本地数据，恢复到完全未使用的状态',
              style: TextStyle(color: tokens.textSecondary, fontSize: 12),
            ),
            onTap: () => _showResetDialog(context, ref),
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

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置所有数据'),
        content: const Text(
          '此操作将清除：\n'
          '• 所有 Firestore 数据（学习进度、设置、收藏等）\n'
          '• 所有本地数据（通知排程、缓存等）\n'
          '• 所有已排程的通知\n\n'
          '此操作无法撤销，确定要继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _performReset(context, ref);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确定重置'),
          ),
        ],
      ),
    );
  }

  Future<void> _performReset(BuildContext context, WidgetRef ref) async {
    // 显示详细的加载对话框
    final progressNotifier = ValueNotifier<String>('准备重置...');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ValueListenableBuilder<String>(
              valueListenable: progressNotifier,
              builder: (context, progress, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(progress),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final resetService = ResetService();
      
      progressNotifier.value = '正在清除云端数据...';
      await Future.delayed(const Duration(milliseconds: 100)); // 让 UI 更新
      
      await resetService.resetAll();
      
      progressNotifier.value = '正在刷新界面...';

      // 关闭加载对话框
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // 显示成功消息
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 重置完成！app 已恢复到完全未使用的状态'),
            duration: Duration(seconds: 3),
          ),
        );
      }

      // 刷新所有 provider
      ref.invalidate(libraryProductsProvider);
      ref.invalidate(wishlistProvider);
      ref.invalidate(savedItemsProvider);
      ref.invalidate(globalPushSettingsProvider);
    } catch (e) {
      // 关闭加载对话框
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // 显示错误消息
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 重置失败: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }

      if (kDebugMode) {
        debugPrint('重置失败: $e');
      }
    } finally {
      // 释放资源
      progressNotifier.dispose();
    }
  }
}
