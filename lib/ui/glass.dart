import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: tokens.glassBlurSigma, sigmaY: tokens.glassBlurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: tokens.cardGradient,
            color: tokens.cardGradient == null ? tokens.cardBg : null,
            border: Border.all(color: tokens.cardBorder),
            boxShadow: tokens.cardShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}
