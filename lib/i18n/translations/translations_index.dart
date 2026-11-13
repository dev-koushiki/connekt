// Central Registry of all 22 supported languages
import 'en.dart';
import 'hi.dart';
import 'bn.dart';
import 'ta.dart';
import 'te.dart';
import 'mr.dart';
import 'gu.dart';
import 'kn.dart';
import 'ml.dart';
import 'pa.dart';
import 'ur.dart';
import 'es.dart';
import 'fr.dart';
import 'de.dart';
import 'pt.dart';
import 'ar.dart';
import 'zh.dart';
import 'ja.dart';
import 'ko.dart';
import 'ru.dart';
import 'it.dart';
import 'id.dart';

class TranslationsRegistry {
  static const Map<String, Map<String, dynamic>> all = {
  'en': enTranslations,
  'hi': hiTranslations,
  'bn': bnTranslations,
  'ta': taTranslations,
  'te': teTranslations,
  'mr': mrTranslations,
  'gu': guTranslations,
  'kn': knTranslations,
  'ml': mlTranslations,
  'pa': paTranslations,
  'ur': urTranslations,
  'es': esTranslations,
  'fr': frTranslations,
  'de': deTranslations,
  'pt': ptTranslations,
  'ar': arTranslations,
  'zh': zhTranslations,
  'ja': jaTranslations,
  'ko': koTranslations,
  'ru': ruTranslations,
  'it': itTranslations,
  'id': idTranslations,
  };

  /// Fallback to English dictionary
  static const Map<String, dynamic> fallback = enTranslations;

  /// Retrieve localized value by dot-notation key (e.g. 'dashboard.scheduler')
  static String get(String langCode, String key, [Map<String, dynamic>? args]) {
    final dict = all[langCode.toLowerCase()] ?? fallback;
    final value = _findKey(dict, key) ?? _findKey(fallback, key) ?? key;

    if (args == null || args.isEmpty) {
      return value;
    }

    String interpolated = value;
    args.forEach((k, v) {
      interpolated = interpolated.replaceAll('{$k}', v.toString());
    });
    return interpolated;
  }

  static String? _findKey(Map<String, dynamic> dict, String key) {
    if (key.contains('.')) {
      final parts = key.split('.');
      dynamic current = dict;
      for (final p in parts) {
        if (current is Map<String, dynamic> && current.containsKey(p)) {
          current = current[p];
        } else {
          return null;
        }
      }
      return current is String ? current : null;
    }
    return dict[key] as String?;
  }
}
