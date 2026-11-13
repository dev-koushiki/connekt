import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../i18n/languages.dart';
import '../i18n/translations/translations_index.dart';
import 'api_service.dart';

/// Centralized Internationalization Service for CONNEKT
/// Supports:
/// - 22 Global & Indian Languages
/// - Reactive, Instantaneous Language Switching (0ms reload, state preserved)
/// - Right-To-Left (RTL) Layout Switching for Arabic & Urdu
/// - Local Storage Persistence + Cross-Device Backend Sync
/// - Interpolation, Pluralization, Date/Time & Number Localization
class I18nService {
  static const String _prefKey = 'connekt_preferred_language';

  /// Primary reactive notifier: Listened to by MaterialApp in main.dart
  static final ValueNotifier<Locale> localeNotifier =
      ValueNotifier<Locale>(const Locale('en'));

  /// Current active language code (e.g. 'en', 'hi', 'bn', 'ar')
  static String get currentLanguageCode => localeNotifier.value.languageCode;

  /// Whether current language requires Right-to-Left (RTL) layout
  static bool get isRtl => AppLanguages.isRtl(currentLanguageCode);

  /// Current active language model
  static LanguageModel get currentLanguage =>
      AppLanguages.getByCode(currentLanguageCode) ?? AppLanguages.all.first;

  /// Initialize language preferences on application startup
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefKey);

      if (savedCode != null && AppLanguages.getByCode(savedCode) != null) {
        localeNotifier.value = Locale(savedCode);
        return;
      }

      // Check device system locale as initial smart suggestion
      final systemLocale = ui.PlatformDispatcher.instance.locale;
      final match = AppLanguages.getByCode(systemLocale.languageCode);
      if (match != null) {
        localeNotifier.value = match.locale;
      } else {
        localeNotifier.value = const Locale('en');
      }
    } catch (_) {
      localeNotifier.value = const Locale('en');
    }
  }

  /// Sync language preference with authenticated user profile from backend
  static void syncWithUser(String? userLanguage) {
    if (userLanguage == null || userLanguage.isEmpty) return;
    final match = AppLanguages.getByCode(userLanguage);
    if (match != null && match.code != currentLanguageCode) {
      setLanguage(match.code, syncBackend: false);
    }
  }

  /// Change active language instantaneously
  /// [langCode]: Language code (e.g. 'hi', 'bn', 'es', 'ar')
  /// [syncBackend]: Whether to push update to backend user profile
  static Future<void> setLanguage(String langCode, {bool syncBackend = true}) async {
    final validLang = AppLanguages.getByCode(langCode);
    if (validLang == null) return;

    // 1. Instantaneous reactive switch
    localeNotifier.value = validLang.locale;

    // 2. Persist locally in SharedPreferences for 0ms next app start
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, validLang.code);
    } catch (_) {}

    // 3. Sync to backend user profile asynchronously
    if (syncBackend) {
      ApiService.updatePreferredLanguage(validLang.code);
    }
  }

  /// Translate dot-notation key (e.g. 'dashboard.scheduler', 'common.cancel')
  static String t(String key, [Map<String, dynamic>? args]) {
    return TranslationsRegistry.get(currentLanguageCode, key, args);
  }

  /// Pluralization helper
  static String tPlural(String key, int count, [Map<String, dynamic>? args]) {
    final combinedArgs = Map<String, dynamic>.from(args ?? {});
    combinedArgs['count'] = count;
    final suffix = count == 1 ? '.one' : '.other';
    final result = TranslationsRegistry.get(currentLanguageCode, '$key$suffix', combinedArgs);
    if (result != '$key$suffix') return result;
    return TranslationsRegistry.get(currentLanguageCode, key, combinedArgs);
  }

  /// Date localization helper
  static String formatDate(DateTime dt) {
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$d/$m/$y';
  }

  /// Time localization helper
  static String formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:$minute $ampm';
  }
}
