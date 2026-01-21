import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class AppCard extends StatefulWidget {
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
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final card = Container(
      decoration: BoxDecoration(
        gradient: t.cardGradient,
        color: t.cardGradient == null ? t.cardBg : null,
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.cardBorder, width: 1),
        boxShadow: t.cardShadow,
      ),
      child: Padding(padding: widget.padding, child: widget.child),
    );

    final blurred = ClipRRect(
      borderRadius: BorderRadius.circular(t.cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: t.glassBlurSigma, sigmaY: t.glassBlurSigma),
        child: card,
      ),
    );

    final body = (t.glassBlurSigma > 0) ? blurred : card;

    if (widget.onTap == null) return body;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: body,
      ),
    );
  }
}
