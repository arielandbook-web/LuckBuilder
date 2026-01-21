import 'package:flutter/material.dart';
import 'app_theme_id.dart';
import 'app_tokens.dart';

class AppThemes {
  static ThemeData byId(AppThemeId id) {
    switch (id) {
      case AppThemeId.darkNeon:
        return _darkNeon();
      case AppThemeId.whiteMint:
        return _whiteMint();
    }
  }

  static ThemeData _darkNeon() {
    const bg = Color(0xFF0B0E1A);
    const primary = Color(0xFF2EF2E1);

    final tokens = AppTokens(
      bg: bg,
      bgGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0B0E1A),
          Color(0xFF121A35),
          Color(0xFF0B0E1A),
        ],
      ),
      primary: primary,
      textPrimary: Colors.white,
      textSecondary: const Color.fromRGBO(255, 255, 255, 0.72),
      cardBg: const Color.fromRGBO(255, 255, 255, 0.08),
      cardBorder: const Color.fromRGBO(255, 255, 255, 0.14),
      cardRadius: 24,
      cardShadow: const [
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.35),
          blurRadius: 28,
          offset: Offset(0, 12),
        ),
      ],
      cardGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.fromRGBO(255, 255, 255, 0.12),
          Color.fromRGBO(46, 242, 225, 0.08),
          Color.fromRGBO(255, 255, 255, 0.08),
        ],
      ),
      chipBg: const Color.fromRGBO(255, 255, 255, 0.08),
      chipGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.fromRGBO(46, 242, 225, 0.15),
          Color.fromRGBO(255, 255, 255, 0.08),
        ],
      ),
      navBg: const Color.fromRGBO(20, 24, 44, 0.72),
      navGradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.fromRGBO(20, 24, 44, 0.85),
          Color.fromRGBO(11, 14, 26, 0.95),
        ],
      ),
      buttonGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primary,
          primary.withValues(alpha: 0.8),
        ],
      ),
      searchBarGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.fromRGBO(255, 255, 255, 0.12),
          Color.fromRGBO(255, 255, 255, 0.08),
        ],
      ),
      glassBlurSigma: 18,
    );

    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: primary,
        surface: tokens.cardBg,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(fontSize: 15, height: 1.35),
        bodySmall: TextStyle(fontSize: 13, height: 1.35),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color.fromRGBO(255, 255, 255, 0.10),
        hintStyle: const TextStyle(color: Color.fromRGBO(255, 255, 255, 0.60)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide:
              const BorderSide(color: Color.fromRGBO(255, 255, 255, 0.14)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide:
              const BorderSide(color: Color.fromRGBO(255, 255, 255, 0.14)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primary, width: 1.2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
    );

    return base.copyWith(extensions: [tokens]);
  }

  static ThemeData _whiteMint() {
    const bg = Color(0xFFFFFFFF); // ✅ 純白底
    const primary = Color(0xFF25C9B8);

    const tokens = AppTokens(
      bg: bg,
      bgGradient: null, // 純白就不要漸層
      primary: primary,
      textPrimary: const Color(0xFF111827),
      textSecondary: const Color(0xFF6B7280),
      cardBg: const Color(0xFFFFFFFF),
      cardBorder: const Color(0xFFEEF1F6),
      cardRadius: 22,
      cardShadow: const [
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.08),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
      cardGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFF8FCFC),
        ],
      ),
      chipBg: const Color(0xFFF5F7FB),
      chipGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFF5F7FB),
          Color(0xFFE8F5F3),
        ],
      ),
      navBg: const Color.fromRGBO(255, 255, 255, 0.92),
      navGradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.fromRGBO(255, 255, 255, 0.98),
          Color.fromRGBO(255, 255, 255, 0.95),
        ],
      ),
      buttonGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primary,
          Color(0xFF1FB8A8),
        ],
      ),
      searchBarGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFF8F9FA),
          Color(0xFFF0F2F5),
        ],
      ),
      glassBlurSigma: 10,
    );

    final base = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: primary,
        surface: tokens.cardBg,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(fontSize: 15, height: 1.35),
        bodySmall: TextStyle(fontSize: 13, height: 1.35),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF6F7FB),
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFEEF1F6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFEEF1F6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primary, width: 1.2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
    );

    return base.copyWith(extensions: [tokens]);
  }
}
