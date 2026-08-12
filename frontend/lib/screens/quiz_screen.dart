import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../models/lesson.dart';
import '../services/api_service.dart';
import '../services/translations.dart';

class QuizScreen extends StatefulWidget {
  final Lesson lesson;
  const QuizScreen({super.key, required this.lesson});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final List<int?> _selectedAnswers = [];
  int _currentQuestionIndex = 0;
  bool _isCurrentQuestionSubmitted = false;

  @override
  void initState() {
    super.initState();
    _selectedAnswers.addAll(
      List<int?>.filled(widget.lesson.questions.length, null),
    );
  }

  int get _correctCount {
    int count = 0;
    for (int i = 0; i < widget.lesson.questions.length; i++) {
      if (_selectedAnswers[i] == widget.lesson.questions[i].correctIndex) {
        count++;
      }
    }
    return count;
  }

  int _coinsEarned = 0;
  bool _isSubmitting = false;

  Future<void> _submitQuiz() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final correct = _correctCount;

    if (correct < 4) {
      _coinsEarned = 0;
      _showResultsDialog();
      return;
    }

    int coinsEarned = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId != null) {
        final quizResult = await ApiService.submitQuizResult(
          userId,
          widget.lesson.id,
          _selectedAnswers,
          isReplay: widget.lesson.isAlreadyPerfect,
        );
        await ApiService.saveProgress(userId, widget.lesson.id, true);
        // Coins come solely from the quiz result, which already accounts for
        // the Double Coin multiplier on the backend.
        coinsEarned = quizResult['coins_earned'] as int? ?? 0;

        // Sync the global coin balance from the fresh server total so the
        // top bar / shop / profile update live.
        final stats = await ApiService.getUserStats(userId);
        coinsNotifier.value = stats['coins'] ?? coinsNotifier.value;
        streakNotifier.value = stats['streak_count'] ?? streakNotifier.value;
        // Refresh the completed-lessons count so the profile progress bar
        // updates live via completedLessonsNotifier.
        final progress = await ApiService.fetchProgress(userId);
        completedLessonsNotifier.value =
            progress.where((p) => p['is_completed'] == true).length;
      }
    } catch (_) {}
    // _coinsEarned is set BEFORE the dialog is shown so it never renders 0.
    _coinsEarned = coinsEarned;

    _showResultsDialog();
  }

  // Uses a Quiz Shield to pass a 3/5 result: consumes one shield, saves the
  // lesson as completed (no quiz coins since score < 4) and returns to roadmap.
  Future<void> _useQuizShield(BuildContext dialogContext) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;

    final result = await ApiService.useItem(userId, 'quiz_shield');
    if (!mounted) return;

    if (result.containsKey('error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Quiz Shield available 🛡️')),
      );
      return;
    }

    // Treat the quiz as passed: save progress (award 0 quiz coins).
    await ApiService.saveProgress(userId, widget.lesson.id, true);
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showResultsDialog() {
    final total = widget.lesson.questions.length;
    final correct = _correctCount;
    final coinsEarned = _coinsEarned;
    final isPass = correct >= 4;

    String title;
    if (correct == total) {
      title = 'Perfect!';
    } else if (correct == total - 1) {
      title = 'Great job! 😊';
    } else if (correct == 3) {
      title = 'Good try, but try again 🙁';
    } else {
      title = 'Try again 😔';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              if (isPass) const Icon(
                Icons.emoji_events,
                color: Color(0xFFFFD700),
                size: 48,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isPass
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFF555555),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${TranslationService.translate(context, 'you_scored')} $correct ${TranslationService.translate(context, 'out_of')} $total',
                style:
                    const TextStyle(fontSize: 17, color: Color(0xFF555555)),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9C4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFFFFD600), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on,
                        color: Colors.amber, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      '${TranslationService.translate(context, 'you_earned')} $coinsEarned ${TranslationService.translate(context, 'coins_reward')}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF856404),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (isPass)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context)
                          .popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF58CC02),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    child: Text(
                      TranslationService.translate(context, 'back_to_roadmap'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _coinsEarned = 0;
                            setState(() {
                              _currentQuestionIndex = 0;
                              _isCurrentQuestionSubmitted = false;
                              _selectedAnswers.fillRange(
                                  0, _selectedAnswers.length, null);
                              _isSubmitting = false;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                          child: Text(
                            TranslationService.translate(context, 'try_again'),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    // Quiz Shield rescue: only offered on an exact 3/5 result.
                    if (correct == 3) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () => _useQuizShield(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF58CC02),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Use Quiz Shield 🛡️',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final qIndex = _currentQuestionIndex;
    final question = lesson.questions[qIndex];
    final hasSelection = _selectedAnswers[qIndex] != null;
    final isLastQuestion = qIndex == lesson.questions.length - 1;
    final progress = (qIndex + 1) / lesson.questions.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: const Color(0xFFE0E0E0),
                  color: const Color(0xFF58CC02),
                  minHeight: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${qIndex + 1}/${lesson.questions.length}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF58CC02),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE0E0E0)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TranslatedText(
                        'Module ${lesson.moduleNumber} · ${lesson.sectionName}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TranslatedText(
                      lesson.title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _QuestionCard(
                      questionIndex: qIndex,
                      question: question,
                      selectedOptionIndex: _selectedAnswers[qIndex],
                      submitted: _isCurrentQuestionSubmitted,
                      onSelect: _isCurrentQuestionSubmitted
                          ? null
                          : (optionIndex) {
                              setState(() =>
                                  _selectedAnswers[qIndex] = optionIndex);
                            },
                    ),
                    // Correction banner: shown when wrong answer submitted
                    if (_isCurrentQuestionSubmitted &&
                        _selectedAnswers[qIndex] != null &&
                        _selectedAnswers[qIndex] != question.correctIndex) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFF58CC02), width: 1.5),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle,
                                color: Color(0xFF58CC02), size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    TranslationService.translate(
                                        context, 'correct_answer_was'),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TranslatedText(
                                    question.options[question.correctIndex],
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: !hasSelection || _isSubmitting
                      ? null
                      : () {
                          if (!_isCurrentQuestionSubmitted) {
                            setState(() {
                              _isCurrentQuestionSubmitted = true;
                            });
                          } else {
                            if (isLastQuestion) {
                              _submitQuiz();
                            } else {
                              setState(() {
                                _currentQuestionIndex++;
                                _isCurrentQuestionSubmitted = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !hasSelection
                        ? const Color(0xFFE0E0E0)
                        : (_isCurrentQuestionSubmitted
                            ? const Color(0xFF58CC02)
                            : const Color(0xFF2196F3)),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: hasSelection ? 3 : 0,
                  ),
                  child: Text(
                    !_isCurrentQuestionSubmitted
                        ? TranslationService.translate(context, 'check_answer')
                        : (isLastQuestion
                            ? TranslationService.translate(context, 'finish_quiz')
                            : TranslationService.translate(context, 'next')),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int questionIndex;
  final QuizQuestion question;
  final int? selectedOptionIndex;
  final bool submitted;
  final void Function(int)? onSelect;

  const _QuestionCard({
    required this.questionIndex,
    required this.question,
    required this.selectedOptionIndex,
    required this.submitted,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Q${questionIndex + 1}.  ',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
                height: 1.4,
              ),
            ),
            Expanded(
              child: TranslatedText(
                question.question,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(question.options.length, (optIndex) {
          final isSelected = selectedOptionIndex == optIndex;
          final isCorrect = question.correctIndex == optIndex;

          Color bgColor = Colors.white;
          Color borderColor = const Color(0xFFE0E0E0);
          Color textColor = const Color(0xFF333333);
          Widget? trailingIcon;

          if (submitted) {
            if (isCorrect) {
              bgColor = const Color(0xFFE8F5E9);
              borderColor = const Color(0xFF58CC02);
              textColor = const Color(0xFF2E7D32);
              trailingIcon = const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF58CC02), size: 22);
            } else if (isSelected && !isCorrect) {
              bgColor = const Color(0xFFFDECEC);
              borderColor = Colors.redAccent;
              textColor = const Color(0xFFC62828);
              trailingIcon = const Icon(Icons.cancel_rounded,
                  color: Colors.redAccent, size: 22);
            }
          } else if (isSelected) {
            bgColor = const Color(0xFFE3F2FD);
            borderColor = const Color(0xFF2196F3);
            textColor = const Color(0xFF1976D2);
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: onSelect != null ? () => onSelect!(optIndex) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected || (submitted && isCorrect)
                            ? borderColor
                            : const Color(0xFFF0F0F0),
                      ),
                      child: Center(
                        child: Text(
                          ['A', 'B', 'C', 'D'][optIndex],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected || (submitted && isCorrect)
                                ? Colors.white
                                : const Color(0xFF888888),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TranslatedText(
                        question.options[optIndex],
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (trailingIcon != null) ...[
                      const SizedBox(width: 8),
                      trailingIcon,
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
