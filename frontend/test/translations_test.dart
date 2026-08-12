import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/translations.dart';

void main() {
  test('all languages define the same set of translation keys', () {
    final translations = TranslationService.staticTranslations;
    final languages = translations.keys.toList();
    final referenceKeys = translations[languages.first]!.keys.toSet();

    for (final lang in languages) {
      final keys = translations[lang]!.keys.toSet();
      final missing = referenceKeys.difference(keys);
      final extra = keys.difference(referenceKeys);
      expect(missing, isEmpty,
          reason: 'Language "$lang" is missing keys: $missing');
      expect(extra, isEmpty,
          reason: 'Language "$lang" has extra keys not in "${languages.first}": $extra');
    }
  });

  test('mascot tutorial keys exist in every language', () {
    final translations = TranslationService.staticTranslations;
    const tutorialKeys = [
      'guide_name',
      'guide_intro_1',
      'guide_intro_2',
      'guide_intro_3',
      'skip',
      'quiz_load_error',
      'quiz_load_error_desc',
    ];

    for (final lang in translations.keys) {
      for (final key in tutorialKeys) {
        expect(translations[lang]!.containsKey(key), isTrue,
            reason: 'Language "$lang" is missing tutorial key "$key"');
        expect(translations[lang]![key], isNotEmpty,
            reason: 'Language "$lang" has an empty value for "$key"');
      }
    }
  });
}
