import 'package:flutter/material.dart';

enum LanguageRegion { indian, international }

class LanguageModel {
  final String code;
  final String name;
  final String nativeName;
  final bool isRtl;
  final LanguageRegion region;
  final String flagEmoji;

  const LanguageModel({
    required this.code,
    required this.name,
    required this.nativeName,
    this.isRtl = false,
    required this.region,
    required this.flagEmoji,
  });

  Locale get locale => Locale(code);

  /// Display title combining Native script and English
  String get displayTitle => '$nativeName ($name)';
}

/// Comprehensive metadata list of all 22 officially supported languages
class AppLanguages {
  static const List<LanguageModel> all = [
    // --- INDIAN LANGUAGES (11) ---
    LanguageModel(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      region: LanguageRegion.indian,
      flagEmoji: '🌐',
    ),
    LanguageModel(
      code: 'hi',
      name: 'Hindi',
      nativeName: 'हिन्दी',
      region: LanguageRegion.indian,
      flagEmoji: '🇮🇳',
    ),
    LanguageModel(
      code: 'bn',
      name: 'Bengali',
      nativeName: 'বাংলা',
      region: LanguageRegion.indian,
      flagEmoji: '🇧🇩',
    ),
    LanguageModel(
      code: 'ta',
      name: 'Tamil',
      nativeName: 'தமிழ்',
      region: LanguageRegion.indian,
      flagEmoji: '🇮🇳',
    ),
    LanguageModel(
      code: 'te',
      name: 'Telugu',
      nativeName: 'తెలుగు',
      region: LanguageRegion.indian,
      flagEmoji: '🇮🇳',
    ),
    LanguageModel(
      code: 'mr',
      name: 'Marathi',
      nativeName: 'मराठी',
      region: LanguageRegion.indian,
      flagEmoji: '🇮🇳',
    ),
    LanguageModel(
      code: 'gu',
      name: 'Gujarati',
      nativeName: 'ગુજરાતી',
      region: LanguageRegion.indian,
      flagEmoji: '🇮🇳',
    ),
    LanguageModel(
      code: 'kn',
      name: 'Kannada',
      nativeName: 'ಕನ್ನಡ',
      region: LanguageRegion.indian,
      flagEmoji: '🇮🇳',
    ),
    LanguageModel(
      code: 'ml',
      name: 'Malayalam',
      nativeName: 'മലയാളം',
      region: LanguageRegion.indian,
      flagEmoji: '🇮🇳',
    ),
    LanguageModel(
      code: 'pa',
      name: 'Punjabi',
      nativeName: 'ਪੰਜਾਬੀ',
      region: LanguageRegion.indian,
      flagEmoji: '🇮🇳',
    ),
    LanguageModel(
      code: 'ur',
      name: 'Urdu',
      nativeName: 'اردو',
      isRtl: true,
      region: LanguageRegion.indian,
      flagEmoji: '🇵🇰',
    ),

    // --- INTERNATIONAL LANGUAGES (11) ---
    LanguageModel(
      code: 'es',
      name: 'Spanish',
      nativeName: 'Español',
      region: LanguageRegion.international,
      flagEmoji: '🇪🇸',
    ),
    LanguageModel(
      code: 'fr',
      name: 'French',
      nativeName: 'Français',
      region: LanguageRegion.international,
      flagEmoji: '🇫🇷',
    ),
    LanguageModel(
      code: 'de',
      name: 'German',
      nativeName: 'Deutsch',
      region: LanguageRegion.international,
      flagEmoji: '🇩🇪',
    ),
    LanguageModel(
      code: 'pt',
      name: 'Portuguese',
      nativeName: 'Português',
      region: LanguageRegion.international,
      flagEmoji: '🇵🇹',
    ),
    LanguageModel(
      code: 'ar',
      name: 'Arabic',
      nativeName: 'العربية',
      isRtl: true,
      region: LanguageRegion.international,
      flagEmoji: '🇸🇦',
    ),
    LanguageModel(
      code: 'zh',
      name: 'Chinese (Simplified)',
      nativeName: '简体中文',
      region: LanguageRegion.international,
      flagEmoji: '🇨🇳',
    ),
    LanguageModel(
      code: 'ja',
      name: 'Japanese',
      nativeName: '日本語',
      region: LanguageRegion.international,
      flagEmoji: '🇯🇵',
    ),
    LanguageModel(
      code: 'ko',
      name: 'Korean',
      nativeName: '한국어',
      region: LanguageRegion.international,
      flagEmoji: '🇰🇷',
    ),
    LanguageModel(
      code: 'ru',
      name: 'Russian',
      nativeName: 'Русский',
      region: LanguageRegion.international,
      flagEmoji: '🇷🇺',
    ),
    LanguageModel(
      code: 'it',
      name: 'Italian',
      nativeName: 'Italiano',
      region: LanguageRegion.international,
      flagEmoji: '🇮🇹',
    ),
    LanguageModel(
      code: 'id',
      name: 'Indonesian',
      nativeName: 'Bahasa Indonesia',
      region: LanguageRegion.international,
      flagEmoji: '🇮🇩',
    ),
  ];

  static final Map<String, LanguageModel> _map = {
    for (var l in all) l.code: l,
  };

  static LanguageModel? getByCode(String code) => _map[code.toLowerCase()];

  static bool isRtl(String code) => _map[code.toLowerCase()]?.isRtl ?? false;

  static List<Locale> get supportedLocales => all.map((l) => l.locale).toList();
}
