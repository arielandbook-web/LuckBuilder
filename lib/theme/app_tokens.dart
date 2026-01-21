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
  final Gradient? cardGradient;

  final Color chipBg;
  final Gradient? chipGradient;

  final Color navBg;
  final Gradient? navGradient;

  final Gradient? buttonGradient;
  final Gradient? searchBarGradient;

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
    this.cardGradient,
    required this.chipBg,
    this.chipGradient,
    required this.navBg,
    this.navGradient,
    this.buttonGradient,
    this.searchBarGradient,
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
    Gradient? cardGradient,
    Color? chipBg,
    Gradient? chipGradient,
    Color? navBg,
    Gradient? navGradient,
    Gradient? buttonGradient,
    Gradient? searchBarGradient,
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
      cardGradient: cardGradient ?? this.cardGradient,
      chipBg: chipBg ?? this.chipBg,
      chipGradient: chipGradient ?? this.chipGradient,
      navBg: navBg ?? this.navBg,
      navGradient: navGradient ?? this.navGradient,
      buttonGradient: buttonGradient ?? this.buttonGradient,
      searchBarGradient: searchBarGradient ?? this.searchBarGradient,
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
      cardGradient: t < 0.5 ? cardGradient : other.cardGradient,
      chipBg: Color.lerp(chipBg, other.chipBg, t)!,
      chipGradient: t < 0.5 ? chipGradient : other.chipGradient,
      navBg: Color.lerp(navBg, other.navBg, t)!,
      navGradient: t < 0.5 ? navGradient : other.navGradient,
      buttonGradient: t < 0.5 ? buttonGradient : other.buttonGradient,
      searchBarGradient: t < 0.5 ? searchBarGradient : other.searchBarGradient,
      glassBlurSigma: lerpDouble(glassBlurSigma, other.glassBlurSigma, t)!,
    );
  }
}

extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
