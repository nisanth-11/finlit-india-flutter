import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/dialogue_service.dart';

void main() {
  test('getCharacterEmoji returns the guide compass emoji, case-insensitively',
      () {
    final service = DialogueService();
    expect(service.getCharacterEmoji('guide'), '🧭');
    expect(service.getCharacterEmoji('Guide'), '🧭');
  });
}
