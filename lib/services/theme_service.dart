import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available app visual themes
enum AppVisualTheme {
  dark,          // Classic Dark Mood (Navy / Slate)
  light,         // Classic Light Mood (Crisp White / Slate)
  midnightGold,  // Cosmic / Midnight Blue & Gold (2nd image)
  luxuryGold,    // Luxury Obsidian Black & Warm Gold (3rd image)
  system,        // System automatic
}

/// Centralized service to manage and persist theme preferences (Light, Dark, Gold themes, System)
class ThemeService {
  static const String _prefModeKey = 'connekt_theme_mode';
  static const String _prefVisualKey = 'connekt_visual_theme';

  /// Reactive notifier for the exact visual theme
  static final ValueNotifier<AppVisualTheme> visualThemeNotifier =
      ValueNotifier<AppVisualTheme>(AppVisualTheme.dark);

  /// Reactive notifier for Flutter ThemeMode (for MaterialApp compatibility)
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  /// Load persisted theme preference from SharedPreferences
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVisual = prefs.getString(_prefVisualKey);
      final savedMode = prefs.getString(_prefModeKey);

      if (savedVisual == 'midnight_gold') {
        _applyVisualTheme(AppVisualTheme.midnightGold);
      } else if (savedVisual == 'luxury_gold') {
        _applyVisualTheme(AppVisualTheme.luxuryGold);
      } else if (savedVisual == 'light' || savedMode == 'light') {
        _applyVisualTheme(AppVisualTheme.light);
      } else if (savedVisual == 'system' || savedMode == 'system') {
        _applyVisualTheme(AppVisualTheme.system);
      } else {
        _applyVisualTheme(AppVisualTheme.dark);
      }
    } catch (_) {
      _applyVisualTheme(AppVisualTheme.dark);
    }
  }

  static void _applyVisualTheme(AppVisualTheme theme) {
    visualThemeNotifier.value = theme;
    switch (theme) {
      case AppVisualTheme.light:
        themeModeNotifier.value = ThemeMode.light;
        break;
      case AppVisualTheme.system:
        themeModeNotifier.value = ThemeMode.system;
        break;
      case AppVisualTheme.dark:
      case AppVisualTheme.midnightGold:
      case AppVisualTheme.luxuryGold:
        themeModeNotifier.value = ThemeMode.dark;
        break;
    }
  }

  /// Set and persist a specific AppVisualTheme
  static Future<void> setVisualTheme(AppVisualTheme theme) async {
    _applyVisualTheme(theme);
    try {
      final prefs = await SharedPreferences.getInstance();
      String visualStr = 'dark';
      String modeStr = 'dark';
      switch (theme) {
        case AppVisualTheme.light:
          visualStr = 'light';
          modeStr = 'light';
          break;
        case AppVisualTheme.system:
          visualStr = 'system';
          modeStr = 'system';
          break;
        case AppVisualTheme.midnightGold:
          visualStr = 'midnight_gold';
          modeStr = 'dark';
          break;
        case AppVisualTheme.luxuryGold:
          visualStr = 'luxury_gold';
          modeStr = 'dark';
          break;
        case AppVisualTheme.dark:
          visualStr = 'dark';
          modeStr = 'dark';
          break;
      }
      await prefs.setString(_prefVisualKey, visualStr);
      await prefs.setString(_prefModeKey, modeStr);
    } catch (_) {}
  }

  /// Set and persist a standard ThemeMode (backward compatible)
  static Future<void> setThemeMode(ThemeMode mode) async {
    switch (mode) {
      case ThemeMode.light:
        await setVisualTheme(AppVisualTheme.light);
        break;
      case ThemeMode.system:
        await setVisualTheme(AppVisualTheme.system);
        break;
      case ThemeMode.dark:
        await setVisualTheme(AppVisualTheme.dark);
        break;
    }
  }

  /// Toggle between Dark and Light mode
  static Future<void> toggleTheme() async {
    if (visualThemeNotifier.value == AppVisualTheme.light) {
      await setVisualTheme(AppVisualTheme.dark);
    } else {
      await setVisualTheme(AppVisualTheme.light);
    }
  }

  /// Helper getters for theme queries
  static bool get isMidnightGold =>
      visualThemeNotifier.value == AppVisualTheme.midnightGold;

  static bool get isLuxuryGold =>
      visualThemeNotifier.value == AppVisualTheme.luxuryGold;

  static bool get isGoldTheme => isMidnightGold || isLuxuryGold;

  /// Helper to determine if currently rendered mode is dark
  static bool isDark(BuildContext context) {
    if (visualThemeNotifier.value == AppVisualTheme.light) return false;
    if (visualThemeNotifier.value == AppVisualTheme.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return true; // dark, midnightGold, luxuryGold are dark variants
  }
}
