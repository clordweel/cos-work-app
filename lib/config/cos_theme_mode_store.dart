import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kPrefsThemeMode = 'cos_theme_mode';

/// 浅色 / 深色 / 跟随系统，持久化 SharedPreferences。
class CosThemeModeStore extends ChangeNotifier {
  CosThemeModeStore._();
  static final CosThemeModeStore instance = CosThemeModeStore._();

  ThemeMode _themeMode = ThemeMode.system;
  bool _initialized = false;

  ThemeMode get themeMode => _themeMode;

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _themeMode = _parse(prefs.getString(_kPrefsThemeMode));
    _initialized = true;
    notifyListeners();
  }

  static ThemeMode _parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    final v = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_kPrefsThemeMode, v);
    notifyListeners();
  }
}
