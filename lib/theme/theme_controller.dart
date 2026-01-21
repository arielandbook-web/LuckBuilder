import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme_id.dart';

class ThemeController extends ChangeNotifier {
  static const _key = 'app_theme_id';

  AppThemeId _id = AppThemeId.darkNeon;
  AppThemeId get id => _id;

  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw != null) {
      _id = AppThemeId.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => AppThemeId.darkNeon,
      );
    }
    notifyListeners();
  }

  Future<void> setTheme(AppThemeId id) async {
    _id = id;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, id.name);
  }

  Future<void> toggle() async {
    await setTheme(_id == AppThemeId.darkNeon
        ? AppThemeId.whiteMint
        : AppThemeId.darkNeon);
  }
}
