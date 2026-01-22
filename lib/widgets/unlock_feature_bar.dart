// lib/widgets/unlock_feature_bar.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../paywall/paywall_controller.dart';
import '../paywall/paywall_state.dart';

class UnlockProductBar extends ConsumerWidget {
  final String productId;   // ✅ 單一 IAP 的 id
  final String priceText;   // 例如 NT$79
  final VoidCallback? onUnlocked; // ✅ 解鎖成功後要做的事（例如開啟詳情/加入購買）

  const UnlockProductBar({
    super.key,
    required this.productId,
    required this.priceText,
    this.onUnlocked,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paywallControllerProvider(productId));
    final ctrl = ref.read(paywallControllerProvider(productId).notifier);

    final isPurchasing = state.status == PaywallStatus.purchasing;
    final isUnlocked = state.status == PaywallStatus.unlocked;

    final title = switch (state.status) {
      PaywallStatus.unlocked => '已解鎖本產品',
      PaywallStatus.purchasing => '處理中…',
      PaywallStatus.error => '未完成購買',
      _ => '解鎖本產品',
    };

    final subtitle = switch (state.status) {
      PaywallStatus.unlocked => '可完整瀏覽詳情並加入橫幅學習',
      PaywallStatus.purchasing => '正在與 App Store 確認',
      PaywallStatus.error => state.errorMessage ?? '你可以再試一次，或使用恢復購買',
      _ => '購買後可看完整詳情＋啟用橫幅推播',
    };

    final buttonText = switch (state.status) {
      PaywallStatus.unlocked => '開始學習',
      PaywallStatus.purchasing => '處理中…',
      PaywallStatus.error => '再試一次',
      _ => '$priceText 立即購買',
    };

    final onPressed = isPurchasing
        ? null
        : () async {
            if (isUnlocked) {
              onUnlocked?.call();
              return;
            }
            await ctrl.purchase();
            // 如果購買成功，呼叫 callback（例如把產品加入已購買、開啟推播）
            final latest = ref.read(paywallControllerProvider(productId));
            if (latest.status == PaywallStatus.unlocked) {
              onUnlocked?.call();
            }
          };

    return _NeonGlassBar(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // 左側文案
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.95),
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          height: 1.25,
                          color: Colors.white.withOpacity(0.72),
                        ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: isPurchasing ? null : ctrl.restore,
                    child: Text(
                      '恢復購買',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white.withOpacity(0.70),
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white.withOpacity(0.35),
                          ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // 右側膠囊按鈕
            _CapsuleButton(
              text: buttonText,
              loading: isPurchasing,
              onPressed: onPressed,
            ),
          ],
        ),
      ),
    );
  }
}

/// 霓虹玻璃底條（用 BackdropFilter 做 blur）
/// 不指定顏色 token 也能運作，若你已有 token 可替換。
class _NeonGlassBar extends StatelessWidget {
  final Widget child;
  const _NeonGlassBar({required this.child});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          // 背後模糊
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(),
          ),

          // 霓虹漸層（青綠）+ 玻璃
          Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  const Color(0xFF2FE6D6).withOpacity(0.70),
                  const Color(0xFF25D8C8).withOpacity(0.55),
                  const Color(0xFF1EC7B7).withOpacity(0.45),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 18,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                  color: Colors.black.withOpacity(0.25),
                ),
              ],
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _CapsuleButton extends StatelessWidget {
  final String text;
  final bool loading;
  final VoidCallback? onPressed;

  const _CapsuleButton({
    required this.text,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: onPressed == null ? 0.72 : 1,
      child: GestureDetector(
        onTap: onPressed,
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // blur 背景
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  color: Colors.white.withOpacity(0.16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.20),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (loading) ...[
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(0.90),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      text,
                      style:
                          Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Colors.white.withOpacity(0.95),
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
