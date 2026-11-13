import 'package:flutter/material.dart';
import '../services/i18n_service.dart';
import 'languages.dart';

/// Standard Flutter Localizations delegate & container
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// Translate key
  String translate(String key, [Map<String, dynamic>? args]) {
    return I18nService.t(key, args);
  }

  /// Check RTL
  bool get isRtl => I18nService.isRtl;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLanguages.getByCode(locale.languageCode) != null;
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Handy extension on BuildContext for effortless translation across all screens
extension TranslationExtension on BuildContext {
  /// Translate a key using current active language (e.g. `context.tr('dashboard.scheduler')`)
  String tr(String key, [Map<String, dynamic>? args]) {
    return I18nService.t(key, args);
  }

  /// Whether current language is RTL (Arabic, Urdu)
  bool get isRtl => I18nService.isRtl;

  /// Active language code
  String get currentLangCode => I18nService.currentLanguageCode;
}
