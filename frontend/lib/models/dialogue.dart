abstract class DialogueItem {
  final int id;
  final String type;

  const DialogueItem({required this.id, required this.type});

  factory DialogueItem.fromJson(Map<String, dynamic> json) {
    switch (json['type'] as String) {
      case 'message':
        return DialogueMessage.fromJson(json);
      case 'choice':
        return DialogueChoice.fromJson(json);
      case 'fact_card':
        return DialogueFactCard.fromJson(json);
      default:
        throw ArgumentError('Unknown dialogue type: ${json['type']}');
    }
  }
}

class DialogueMessage extends DialogueItem {
  final String character;
  final String text;
  final String? branch;

  const DialogueMessage({
    required super.id,
    required this.character,
    required this.text,
    this.branch,
  }) : super(type: 'message');

  factory DialogueMessage.fromJson(Map<String, dynamic> json) {
    return DialogueMessage(
      id: json['id'] as int,
      character: json['character'] as String,
      text: json['text'] as String,
      branch: json['branch'] as String?,
    );
  }
}

class DialogueOption {
  final String text;
  final String branch;

  const DialogueOption({required this.text, required this.branch});

  factory DialogueOption.fromJson(Map<String, dynamic> json) {
    return DialogueOption(
      text: json['text'] as String,
      branch: json['branch'] as String,
    );
  }
}

class DialogueChoice extends DialogueItem {
  final List<DialogueOption> options;

  const DialogueChoice({
    required super.id,
    required this.options,
  }) : super(type: 'choice');

  factory DialogueChoice.fromJson(Map<String, dynamic> json) {
    return DialogueChoice(
      id: json['id'] as int,
      options: (json['options'] as List<dynamic>)
          .map((o) => DialogueOption.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DialogueFactCard extends DialogueItem {
  final String text;
  final String? branch;
  final String? unlock;

  const DialogueFactCard({
    required super.id,
    required this.text,
    this.branch,
    this.unlock,
  }) : super(type: 'fact_card');

  factory DialogueFactCard.fromJson(Map<String, dynamic> json) {
    return DialogueFactCard(
      id: json['id'] as int,
      text: json['text'] as String,
      branch: json['branch'] as String?,
      unlock: json['unlock'] as String?,
    );
  }
}

class DialogueLesson {
  final int id;
  final String title;
  final List<DialogueItem> messages;

  const DialogueLesson({
    required this.id,
    required this.title,
    required this.messages,
  });

  factory DialogueLesson.fromJson(Map<String, dynamic> json) {
    return DialogueLesson(
      id: json['id'] as int,
      title: json['title'] as String,
      messages: (json['messages'] as List<dynamic>)
          .map((m) => DialogueItem.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}
