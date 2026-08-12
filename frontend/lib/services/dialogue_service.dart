import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/dialogue.dart';

class DialogueService {
  Future<List<DialogueLesson>> loadDialogues() async {
    final String jsonString =
        await rootBundle.loadString('assets/data/dialogues.json');
    final Map<String, dynamic> json =
        jsonDecode(jsonString) as Map<String, dynamic>;
    final List<dynamic> lessons = json['lessons'] as List<dynamic>;
    return lessons
        .map((l) => DialogueLesson.fromJson(l as Map<String, dynamic>))
        .toList();
  }

  Future<DialogueLesson?> loadLessonDialogue(int lessonId) async {
    final lessons = await loadDialogues();
    try {
      return lessons.firstWhere((l) => l.id == lessonId);
    } catch (_) {
      return null;
    }
  }

  String getCharacterEmoji(String character) {
    switch (character.toLowerCase()) {
      case 'sunita':
        return '👩';
      case 'meena':
        return '👵';
      case 'raj':
        return '👨';
      case 'guide':
        return '🧭';
      default:
        return '👤';
    }
  }
}
