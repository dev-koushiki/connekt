import 'package:flutter_test/flutter_test.dart';
import 'package:connekt/i18n/languages.dart';
import 'package:connekt/i18n/translations/translations_index.dart';
import 'package:connekt/services/i18n_service.dart';

void main() {
  group('CONNEKT Internationalization (i18n) System Tests', () {
    test('Verify all 22 officially supported languages are registered', () {
      expect(AppLanguages.all.length, 22);

      final indian = AppLanguages.all.where((l) => l.region == LanguageRegion.indian).toList();
      final international = AppLanguages.all.where((l) => l.region == LanguageRegion.international).toList();

      expect(indian.length, 11);
      expect(international.length, 11);

      // Verify specific required Indian languages
      final indianCodes = indian.map((l) => l.code).toSet();
      expect(indianCodes, containsAll(['en', 'hi', 'bn', 'ta', 'te', 'mr', 'gu', 'kn', 'ml', 'pa', 'ur']));

      // Verify specific required International languages
      final intlCodes = international.map((l) => l.code).toSet();
      expect(intlCodes, containsAll(['es', 'fr', 'de', 'pt', 'ar', 'zh', 'ja', 'ko', 'ru', 'it', 'id']));
    });

    test('Verify RTL (Right-to-Left) languages are properly flagged', () {
      expect(AppLanguages.isRtl('ar'), isTrue);
      expect(AppLanguages.isRtl('ur'), isTrue);
      expect(AppLanguages.isRtl('en'), isFalse);
      expect(AppLanguages.isRtl('hi'), isFalse);
      expect(AppLanguages.isRtl('zh'), isFalse);
    });

    test('Verify translations exist for all 22 languages across core modules', () {
      final requiredModules = ['common', 'dashboard', 'meetings', 'chats', 'mails', 'social', 'profile', 'auth'];

      for (final lang in AppLanguages.all) {
        final dict = TranslationsRegistry.all[lang.code];
        expect(dict, isNotNull, reason: 'Language dictionary for ${lang.code} should exist');

        for (final mod in requiredModules) {
          expect(dict!.containsKey(mod), isTrue, reason: 'Module $mod should exist in ${lang.code}');
          final modMap = dict[mod] as Map<String, dynamic>;
          expect(modMap.isNotEmpty, isTrue, reason: 'Module $mod in ${lang.code} should not be empty');
        }
      }
    });

    test('Verify translation lookup and interpolation', () {
      // English lookup
      final enSchedule = TranslationsRegistry.get('en', 'dashboard.scheduler');
      expect(enSchedule, 'Schedule');

      // Hindi lookup
      final hiSchedule = TranslationsRegistry.get('hi', 'dashboard.scheduler');
      expect(hiSchedule, 'शेड्यूल');

      // Bengali lookup
      final bnSchedule = TranslationsRegistry.get('bn', 'dashboard.scheduler');
      expect(bnSchedule, 'সময়সূচী');

      // Arabic lookup (RTL)
      final arSchedule = TranslationsRegistry.get('ar', 'dashboard.scheduler');
      expect(arSchedule, 'الجدول الزمني');

      // Interpolation test
      final interpolated = TranslationsRegistry.get('en', 'common.language_updated', {'lang': 'Hindi'});
      expect(interpolated, 'Language updated to Hindi');
    });

    test('Verify fallback to English when key is missing in custom language', () {
      // If a non-existent key is queried, it falls back to the key itself or English without throwing
      final fallbackResult = TranslationsRegistry.get('es', 'dashboard.non_existent_key_xyz');
      expect(fallbackResult, 'dashboard.non_existent_key_xyz');
    });

    test('Verify Date and Time localization helpers', () {
      final testDate = DateTime(2026, 11, 13, 14, 30);
      final formattedDate = I18nService.formatDate(testDate);
      expect(formattedDate, '13/11/2026');

      final formattedTime = I18nService.formatTime(testDate);
      expect(formattedTime, '2:30 PM');
    });
  });
}
