import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lesson.dart';
import '../models/dialogue.dart';
import '../services/api_service.dart';
import '../services/dialogue_service.dart';
import '../services/translations.dart';
import 'quiz_screen.dart';

enum _ChatItemType { character, priya, factCard, placeholder }

class _ChatItem {
  final _ChatItemType type;
  final String? character;
  final String text;
  const _ChatItem({required this.type, this.character, required this.text});
}

class LessonScreen extends StatefulWidget {
  final Lesson lesson;

  const LessonScreen({super.key, required this.lesson});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  // Dialogue
  bool _dialogueLoading = true;
  final List<_ChatItem> _chatItems = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<DialogueItem> _pendingItems = [];
  String? _activeBranch;
  DialogueChoice? _awaitingChoice;
  bool _isTyping = false;
  bool _dialogueComplete = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadDialogue();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDialogue() async {
    final lesson = await DialogueService()
        .loadLessonDialogue(widget.lesson.orderIndex);
    if (!mounted) return;
    setState(() {
      _dialogueLoading = false;
      if (lesson != null) {
        _pendingItems.addAll(lesson.messages);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (lesson != null) {
        _processNext();
      } else {
        _insertItem(const _ChatItem(
          type: _ChatItemType.placeholder,
          text: 'Dialogue coming soon',
        ));
        setState(() => _dialogueComplete = true);
      }
    });
  }

  void _processNext() {
    if (_pendingItems.isEmpty) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _dialogueComplete = true;
        });
      }
      return;
    }

    final item = _pendingItems.removeAt(0);

    if (item is DialogueChoice) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _awaitingChoice = item;
        });
      }
      return;
    }

    String? branch;
    if (item is DialogueMessage) branch = item.branch;
    if (item is DialogueFactCard) branch = item.branch;

    if (branch != null && branch != 'merge' && branch != _activeBranch) {
      _processNext();
      return;
    }

    if (mounted) setState(() => _isTyping = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _isTyping = false);
      if (item is DialogueMessage) {
        _insertItem(_ChatItem(
          type: _ChatItemType.character,
          character: item.character,
          text: item.text,
        ));
      } else if (item is DialogueFactCard) {
        _insertItem(_ChatItem(type: _ChatItemType.factCard, text: item.text));
      }
      _processNext();
    });
  }

  void _insertItem(_ChatItem item) {
    final index = _chatItems.length;
    _chatItems.add(item);
    _listKey.currentState
        ?.insertItem(index, duration: const Duration(milliseconds: 300));
    _scrollToBottom();
  }

  void _onChoiceSelected(DialogueOption option) {
    setState(() {
      _awaitingChoice = null;
      _activeBranch = option.branch;
    });
    _insertItem(_ChatItem(type: _ChatItemType.priya, text: option.text));
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _processNext();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TranslatedText(
          widget.lesson.title,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child:
              Container(height: 1, color: const Color(0xFFE0E0E0)),
        ),
      ),
      body: _buildDialogueView(),
    );
  }

  // ── Dialogue view ─────────────────────────────────────────────────────────

  Widget _buildDialogueView() {
    return Column(
      children: [
        Expanded(
          child: _dialogueLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF58CC02),
                    strokeWidth: 2,
                  ),
                )
              : ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(overscroll: false),
                  child: AnimatedList(
                  key: _listKey,
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  padding:
                      const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  initialItemCount: 0,
                  itemBuilder: (context, index, animation) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.15),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut)),
                      child: FadeTransition(
                        opacity: animation,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildChatItem(_chatItems[index]),
                        ),
                      ),
                    );
                  },
                ),
                ),
        ),
        if (_isTyping) _buildTypingIndicator(),
        if (_awaitingChoice != null) _buildChoicePanel(_awaitingChoice!),
        if (_dialogueComplete) _buildStartQuizButton(),
      ],
    );
  }

  Widget _buildChatItem(_ChatItem item) {
    switch (item.type) {
      case _ChatItemType.character:
        return _buildCharacterBubble(item);
      case _ChatItemType.priya:
        return _buildPriyaBubble(item.text);
      case _ChatItemType.factCard:
        return _buildFactCard(item.text);
      case _ChatItemType.placeholder:
        return _buildPlaceholder(item.text);
    }
  }

  Widget _buildPlaceholder(String text) {
    return Center(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCCCCCC), width: 1.5),
        ),
        child: TranslatedText(
          text,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF888888),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildCharacterBubble(_ChatItem item) {
    final emoji = DialogueService().getCharacterEmoji(item.character!);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.character!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TranslatedText(
                  item.text,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1A1A1A),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 52),
      ],
    );
  }

  Widget _buildPriyaBubble(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 52),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                TranslationService.translate(context, 'you') == 'you' ? 'You' : TranslationService.translate(context, 'you'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF58CC02),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(4),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF58CC02).withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TranslatedText(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFactCard(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF81C784), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: TranslatedText(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2E7D32),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const _TypingDots(),
      ),
    );
  }

  Widget _buildChoicePanel(DialogueChoice choice) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            TranslationService.translate(context, 'choose_response'),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF888888),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ...choice.options.map((option) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => _onChoiceSelected(option),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FAF0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF58CC02), width: 1.5),
                    ),
                    child: TranslatedText(
                      option.text,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildStartQuizButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => QuizScreen(lesson: widget.lesson)),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF58CC02),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 2,
            shadowColor: const Color(0xFF58CC02).withValues(alpha: 0.4),
          ),
          child: Text(
            '${TranslationService.translate(context, 'start_quiz')}  →',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// ── Typing animation ───────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_controller.value + i / 3) % 1.0;
            final t = phase < 0.5
                ? Curves.easeInOut.transform(phase * 2)
                : Curves.easeInOut.transform((1.0 - phase) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.translate(
                offset: Offset(0, -5 * t),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Color.lerp(
                        const Color(0xFFCCCCCC),
                        const Color(0xFF888888),
                        t)!,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
