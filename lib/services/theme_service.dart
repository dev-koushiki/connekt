import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized service to manage and persist theme preferences (Light, Dark, System)
class ThemeService {
  static const String _prefKey = 'connekt_theme_mode';

  /// Reactive notifier that triggers immediate rebuilds across the widget tree
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  /// Load persisted theme preference from SharedPreferences
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_prefKey);
      if (savedMode == 'light') {
        themeModeNotifier.value = ThemeMode.light;
      } else if (savedMode == 'system') {
        themeModeNotifier.value = ThemeMode.system;
      } else {
        themeModeNotifier.value = ThemeMode.dark;
      }
    } catch (_) {
      // Fallback gracefully to dark mode if prefs unavailable
      themeModeNotifier.value = ThemeMode.dark;
    }
  }

  /// Set and persist a specific ThemeMode
  static Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      String modeStr = 'dark';
      if (mode == ThemeMode.light) {
        modeStr = 'light';
      } else if (mode == ThemeMode.system) {
        modeStr = 'system';
      }
      await prefs.setString(_prefKey, modeStr);
    } catch (_) {}
  }

  /// Toggle between Dark and Light mode
  static Future<void> toggleTheme() async {
    if (themeModeNotifier.value == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }

  /// Helper to determine if currently rendered mode is dark
  static bool isDark(BuildContext context) {
    if (themeModeNotifier.value == ThemeMode.dark) return true;
    if (themeModeNotifier.value == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }
}
