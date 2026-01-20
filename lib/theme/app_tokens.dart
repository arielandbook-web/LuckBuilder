import 'dart:ui';

import 'package:flutter/material.dart';

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  final Color bg;
  final Gradient? bgGradient;

  final Color primary;
  final Color textPrimary;
  final Color textSecondary;

  final Color cardBg;
  final Color cardBorder;
  final double cardRadius;
  final List<BoxShadow> cardShadow;

  final Color chipBg;
  final Color navBg;

  /// Dark: glass blur > 0; White: blur can be 0 (still fine if you keep blur)
  final double glassBlurSigma;

  const AppTokens({
    required this.bg,
    required this.bgGradient,
    required this.primary,
    required this.textPrimary,
    required this.textSecondary,
    required this.cardBg,
    required this.cardBorder,
    required this.cardRadius,
    required this.cardShadow,
    required this.chipBg,
    required this.navBg,
    required this.glassBlurSigma,
  });

  @override
  AppTokens copyWith({
    Color? bg,
    Gradient? bgGradient,
    Color? primary,
    Color? textPrimary,
    Color? textSecondary,
    Color? cardBg,
    Color? cardBorder,
    double? cardRadius,
    List<BoxShadow>? cardShadow,
    Color? chipBg,
    Color? navBg,
    double? glassBlurSigma,
  }) {
    return AppTokens(
      bg: bg ?? this.bg,
      bgGradient: bgGradient ?? this.bgGradient,
      primary: primary ?? this.primary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      cardBg: cardBg ?? this.cardBg,
      cardBorder: cardBorder ?? this.cardBorder,
      cardRadius: cardRadius ?? this.cardRadius,
      cardShadow: cardShadow ?? this.cardShadow,
      chipBg: chipBg ?? this.chipBg,
      navBg: navBg ?? this.navBg,
      glassBlurSigma: glassBlurSigma ?? this.glassBlurSigma,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      bgGradient: t < 0.5 ? bgGradient : other.bgGradient,
      primary: Color.lerp(primary, other.primary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t)!,
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
      chipBg: Color.lerp(chipBg, other.chipBg, t)!,
      navBg: Color.lerp(navBg, other.navBg, t)!,
      glassBlurSigma: lerpDouble(glassBlurSigma, other.glassBlurSigma, t)!,
    );
  }
}

extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
