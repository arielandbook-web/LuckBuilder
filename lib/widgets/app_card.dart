import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final card = Container(
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.cardBorder),
        boxShadow: t.cardShadow,
      ),
      child: Padding(padding: padding, child: child),
    );

    final blurred = ClipRRect(
      borderRadius: BorderRadius.circular(t.cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: t.glassBlurSigma, sigmaY: t.glassBlurSigma),
        child: card,
      ),
    );

    final body = (t.glassBlurSigma > 0) ? blurred : card;

    if (onTap == null) return body;
    return InkWell(
      borderRadius: BorderRadius.circular(t.cardRadius),
      onTap: onTap,
      child: body,
    );
  }
}
