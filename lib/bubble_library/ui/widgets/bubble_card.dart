import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../theme/app_tokens.dart';

class BubbleCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const BubbleCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  State<BubbleCard> createState() => _BubbleCardState();
}

class _BubbleCardState extends State<BubbleCard>
    with SingleTickerProviderStateMixin {
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
    final tokens = context.tokens;

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(tokens.cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: tokens.glassBlurSigma, sigmaY: tokens.glassBlurSigma),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.cardRadius),
            gradient: tokens.cardGradient,
            color: tokens.cardGradient == null ? tokens.cardBg : null,
            border: Border.all(color: tokens.cardBorder, width: 1),
            boxShadow: tokens.cardShadow,
          ),
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );

    if (widget.onTap == null) return card;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: card,
      ),
    );
  }
}
