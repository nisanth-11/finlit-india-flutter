import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../models/lesson.dart';
import '../services/api_service.dart';
import '../services/translations.dart';
import '../services/tutorial_flags.dart';
import 'lesson_screen.dart';
import 'profile_screen.dart';
import 'budget_screen.dart';
import 'shop_screen.dart';

const _kGreen = Color(0xFF58CC02);
const _kGreenDark = Color(0xFF45A800);
const _kGrey = Color(0xFFAFAFAF);
const _kGreyLight = Color(0xFFE5E5E5);
// Golden states: perfect-score lessons / fully-mastered modules.
const _kGold = Color(0xFFFFC107);
const _kGoldDark = Color(0xFFFFA000);
// WCAG 2.5.5 minimum touch target size.
const double _kMinTapTarget = 44.0;

class RoadmapScreen extends StatefulWidget {
  const RoadmapScreen({super.key});

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  int _selectedIndex = 0;
  // Stable key for the Home tab. It no longer changes on tab taps — the home
  // tab refreshes via onRefresh after returning from a lesson, not by remount.
  final int _homeKey = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _HomeTab(key: ValueKey(_homeKey), isActiveTab: _selectedIndex == 0),
          const ShopScreen(),
          BudgetScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              // Home tab must NOT reload every time it's tapped — it only
              // refreshes after returning from a lesson (see onRefresh).
              // Profile updates live via notifiers, so no force-reload either.
              _selectedIndex = index;
            });
          },
          selectedItemColor: _kGreen,
          unselectedItemColor: _kGrey,
          type: BottomNavigationBarType.fixed, // Use fixed for 5 items
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home_rounded),
              label: TranslationService.translate(context, 'home'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.storefront_outlined),
              activeIcon: const Icon(Icons.storefront_rounded),
              label: TranslationService.translate(context, 'shop'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              activeIcon: const Icon(Icons.account_balance_wallet_rounded),
              label: TranslationService.translate(context, 'budget'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline_rounded),
              activeIcon: const Icon(Icons.person_rounded),
              label: TranslationService.translate(context, 'profile'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Home Tab ─────────────────────────────────────────────────────────────────

class _HomeTab extends StatefulWidget {
  // Whether the Home tab is the currently-selected IndexedStack child.
  // _HomeTab stays mounted (and its State preserved) even when another tab
  // is selected — without gating on this, the intro's PopScope would stay
  // registered with the app's single Route while invisible, and a back-press
  // on a completely different tab would silently fire it too (/review
  // finding, confirmed: two simultaneously-mounted canPop:false PopScopes
  // both invoke their callback on one back-press).
  final bool isActiveTab;

  const _HomeTab({super.key, required this.isActiveTab});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  List<Lesson> _lessons = [];
  bool _isLoading = true;
  // Lesson ids the user has completed with a perfect score (5/5 == "golden").
  Set<String> _perfectLessonIds = {};
  final Map<String, int> _userStats = {'streak': 0, 'coins': 0};

  // Mascot intro (Guide). Checked once _loadData() finishes — after that,
  // there's a real Lesson 1 circle for the highlight/Semantics target to
  // point at, avoiding a race with the loading spinner.
  bool _showIntro = false;
  _IntroStep _introStep = _IntroStep.greeting;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _maybeShowIntro() async {
    if (_lessons.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(TutorialFlags.roadmapIntro) ?? false;
    if (!seen && mounted) {
      setState(() {
        _showIntro = true;
        _introStep = _IntroStep.greeting;
      });
    }
  }

  void _advanceIntro() {
    if (_introStep == _IntroStep.greeting) {
      setState(() => _introStep = _IntroStep.handoff);
    } else if (_introStep == _IntroStep.handoff) {
      setState(() => _introStep = _IntroStep.coinsAndShop);
    } else {
      _dismissIntro();
    }
  }

  // Dismissing the merged walkthrough marks all three tutorial moments seen
  // at once — the walkthrough already covered lesson 1, coins, and the Shop
  // in one sitting, so none of them should trigger separately later.
  Future<void> _dismissIntro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(TutorialFlags.roadmapIntro, true);
    await prefs.setBool(TutorialFlags.shopTip, true);
    await prefs.setBool(TutorialFlags.firstCompletion, true);
    if (mounted) setState(() => _showIntro = false);
  }

  Future<void> _loadData() async {
    // Only the very first load takes over the whole screen; subsequent
    // refreshes keep the roadmap visible — coins/streak update live via
    // their notifiers, so no inline indicator is needed.
    try {
      final lessons = await ApiService.fetchLessons();
      lessons.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      Set<String> perfectIds = {};

      if (userId != null) {
        final progress = await ApiService.fetchProgress(userId);
        final stats = await ApiService.getUserStats(userId);
        final quizResults = await ApiService.fetchQuizResults(userId);
        final completedIds = progress.map((p) => p['lesson_id']).toSet();

        // A lesson is "golden" if any of its quiz results scored 100%.
        for (final r in quizResults) {
          if ((r['score'] ?? 0) == 100 && r['lesson_id'] != null) {
            perfectIds.add(r['lesson_id'] as String);
          }
        }

        if (mounted) {
          setState(() {
            _userStats['streak'] = stats['streak_count'] ?? 0;
            _userStats['coins'] = stats['coins'] ?? 0;
          });
        }
        // Keep the global coin/streak balances in sync so every listener updates.
        coinsNotifier.value = stats['coins'] ?? coinsNotifier.value;
        streakNotifier.value = stats['streak_count'] ?? streakNotifier.value;

        // Update completion status and locking logic
        for (int i = 0; i < lessons.length; i++) {
          final lesson = lessons[i];
          if (completedIds.contains(lesson.id)) {
            lessons[i].isCompleted = true;
          }
          lessons[i].isAlreadyPerfect = perfectIds.contains(lesson.id);
          // Simple locking: lock if previous lesson is not completed (except first)
          if (i > 0 && !lessons[i-1].isCompleted) {
            lessons[i].isLocked = true;
          } else {
            lessons[i].isLocked = false;
          }
        }
      }

      if (mounted) {
        setState(() {
          _lessons = lessons;
          _perfectLessonIds = perfectIds;
          _isLoading = false;
        });
        await _maybeShowIntro();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kGreen));
    }
    final roadmap = Column(
      children: [
        _TopBar(user: _userStats),
        Expanded(
          child: _RoadmapBody(
            lessons: _lessons,
            perfectLessonIds: _perfectLessonIds,
            onRefresh: _loadData,
            tutorialTargetLessonId:
                _showIntro && _lessons.isNotEmpty ? _lessons.first.id : null,
            // The dimming scrim uses IgnorePointer (Item 13: roadmap stays
            // interactive-looking behind it), which means taps DO reach the
            // highlighted lesson circle underneath — and the Guide's own
            // copy tells the user to tap it. If they follow that
            // instruction directly instead of Skip/Next, this callback
            // still dismisses the intro (marks it seen) before navigating,
            // so it doesn't reappear on every future visit (/review fix).
            onTutorialTargetTapped: _showIntro ? _dismissIntro : null,
          ),
        ),
      ],
    );

    // Gated on isActiveTab too, not just _showIntro — _HomeTab stays
    // mounted (and _showIntro stays true) even while another tab is
    // selected. Rendering the overlay+PopScope only while this tab is
    // actually visible avoids a phantom PopScope registration that would
    // otherwise fire on a completely unrelated tab's back-press (/review
    // fix, see the isActiveTab field doc for the confirmed repro).
    if (!_showIntro || !widget.isActiveTab) return roadmap;

    // System back, while the intro is showing, dismisses it the same way
    // Skip does — design doc Item 18 / Open Questions.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _dismissIntro();
      },
      child: Stack(
      children: [
        roadmap,
        // Dimmed scrim — roadmap stays visible behind it, per design review
        // Item 13: user never loses context of where they are.
        Positioned.fill(
          child: IgnorePointer(
            child: Container(color: Colors.black.withValues(alpha: 0.35)),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 16,
          child: _SkipButton(onTap: _dismissIntro),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: _GuideBubble(
            step: _introStep,
            onNext: _advanceIntro,
          ),
        ),
      ],
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SkipButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
              minHeight: _kMinTapTarget, minWidth: _kMinTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          alignment: Alignment.center,
          child: Text(
            TranslationService.translate(context, 'skip'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Guide mascot bubble ───────────────────────────────────────────────────
//
// Reuses lesson_screen.dart's chat-bubble visual language (white bg, 12px
// rounded tail-cut corners, 12px gray name label, 15px dark message text)
// instead of inventing new dialog chrome — see design doc "What already
// exists". step 0 = greeting + spoken instruction (screen-reader parity,
// design review Item 17); step 1 = Guide→Sunita handoff line; step 2 =
// coins + Shop preview, merging what used to be the separate Shop tip and
// first-quiz-completion celebration into this single upfront walkthrough.
enum _IntroStep { greeting, handoff, coinsAndShop }

class _GuideBubble extends StatelessWidget {
  final _IntroStep step;
  final VoidCallback onNext;
  const _GuideBubble({required this.step, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final messageKey = switch (step) {
      _IntroStep.greeting => 'guide_intro_1',
      _IntroStep.handoff => 'guide_intro_2',
      _IntroStep.coinsAndShop => 'guide_intro_3',
    };
    final isLastStep = step == _IntroStep.coinsAndShop;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🧭', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TranslationService.translate(context, 'guide_name'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  TranslationService.translate(context, messageKey),
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1A1A1A),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onNext,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(_kMinTapTarget, _kMinTapTarget),
                    ),
                    child: Text(
                      TranslationService.translate(
                          context, isLastStep ? 'ok' : 'next'),
                      style: const TextStyle(
                        color: _kGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final Map<String, int> user;
  const _TopBar({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 20,
        right: 20,
        bottom: 12,
      ),
      child: Row(
        children: [
          // App title
          const Text(
            'FinLit India',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const Spacer(),
          // Streak — driven by the global notifier so it updates live after a
          // quiz completion without reloading the screen.
          ValueListenableBuilder<int>(
            valueListenable: streakNotifier,
            builder: (context, streak, _) => _TopBarChip(
              label: '$streak',
              icon: Icons.local_fire_department,
              iconColor: Colors.orange,
              color: streak > 0
                  ? const Color(0xFFFFE0B2)
                  : const Color(0xFFF5F5F5),
              textColor: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(width: 8),
          // Coins — driven by the global notifier so it updates live after a
          // quiz reward or shop purchase without reloading the screen.
          ValueListenableBuilder<int>(
            valueListenable: coinsNotifier,
            builder: (context, coins, _) => _TopBarChip(
              label: '$coins',
              icon: Icons.monetization_on,
              iconColor: Colors.amber,
              color: const Color(0xFFFFF9C4),
              textColor: const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBarChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final Color color;
  final Color textColor;

  const _TopBarChip({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.color,
    this.textColor = const Color(0xFF1A1A1A),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Roadmap Body ─────────────────────────────────────────────────────────────

class _RoadmapBody extends StatelessWidget {
  final List<Lesson> lessons;
  final Set<String> perfectLessonIds;
  final VoidCallback onRefresh;
  // Set while the roadmap intro is showing (design doc Premise 12 / Item 16):
  // highlights this lesson's circle with the gold "pay attention here" ring
  // instead of a floating spotlight overlay.
  final String? tutorialTargetLessonId;
  // Called if the user taps the highlighted target lesson directly instead
  // of using Skip/Next — dismisses the intro so it doesn't reappear.
  final VoidCallback? onTutorialTargetTapped;

  static const double _itemHeight = 110.0;
  static const double _circleSize = 72.0;
  static const double _bannerHeight = 72.0;
  // Extra breathing room before a module banner so the previous module's last
  // lesson title doesn't crowd the next header. Not applied to the first banner.
  static const double _bannerTopGap = 32.0;

  // x-fractions cycling: left-center, right-center, center, right-center, left-center
  static const List<double> _xPattern = [0.30, 0.70, 0.50, 0.70, 0.30];

  const _RoadmapBody({
    required this.lessons,
    required this.perfectLessonIds,
    required this.onRefresh,
    this.tutorialTargetLessonId,
    this.onTutorialTargetTapped,
  });

  double _xFraction(int index) =>
      _xPattern[index % _xPattern.length];

  bool _isPerfect(Lesson lesson) => perfectLessonIds.contains(lesson.id);

  @override
  Widget build(BuildContext context) {
    final totalLessons = lessons.length;

    // Per-module mastery: whether every lesson is completed, and whether every
    // lesson is golden (perfect score). Used for the banner gold states.
    final Map<int, List<Lesson>> lessonsByModule = {};
    for (final lesson in lessons) {
      lessonsByModule.putIfAbsent(lesson.moduleNumber, () => []).add(lesson);
    }
    final Map<int, bool> moduleAllCompleted = {};
    final Map<int, bool> moduleAllPerfect = {};
    lessonsByModule.forEach((module, moduleLessons) {
      moduleAllCompleted[module] =
          moduleLessons.every((l) => l.isCompleted);
      moduleAllPerfect[module] =
          moduleLessons.every((l) => _isPerfect(l));
    });

    // Insert section banners: find first index of each new module
    final List<_RoadmapItem> items = [];
    int? lastModule;
    for (int i = 0; i < totalLessons; i++) {
      final lesson = lessons[i];
      if (lesson.moduleNumber != lastModule) {
        items.add(_RoadmapItem.banner(lesson.moduleNumber, lesson.sectionName));
        lastModule = lesson.moduleNumber;
      }
      items.add(_RoadmapItem.lesson(lesson));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // Build list of circle positions for painter (lesson items only)
        final List<Offset> circlePositions = [];
        final List<bool> circleCompleted = [];
        final List<bool> circlePerfect = [];
        final List<int> circleModules = [];
        int lessonIndex = 0;
        double y = 0;
        bool firstItem = true;
        for (final item in items) {
          if (item.isBanner) {
            if (!firstItem) y += _bannerTopGap;
            y += _bannerHeight; // banner height
          } else {
            final x = width * _xFraction(lessonIndex);
            circlePositions.add(Offset(x, y + _itemHeight / 2));
            circleCompleted.add(item.lesson!.isCompleted);
            circlePerfect.add(_isPerfect(item.lesson!));
            circleModules.add(item.lesson!.moduleNumber);
            lessonIndex++;
            y += _itemHeight;
          }
          firstItem = false;
        }

        final double totalHeight = y;

        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: totalHeight + 40,
            child: Stack(
              children: [
                // Connecting path
                CustomPaint(
                  size: Size(width, totalHeight + 40),
                  painter: _RoadmapPainter(
                    positions: circlePositions,
                    isCompleted: circleCompleted,
                    isPerfect: circlePerfect,
                    moduleNumbers: circleModules,
                  ),
                ),
                // Items
                Builder(builder: (context) {
                  final List<Widget> widgets = [];
                  double dy = 0;
                  int lIdx = 0;
                  bool firstWidget = true;
                  for (final item in items) {
                    if (item.isBanner) {
                      if (!firstWidget) dy += _bannerTopGap;
                      widgets.add(Positioned(
                        top: dy,
                        left: 0,
                        right: 0,
                        child: _SectionBanner(
                          moduleNumber: item.moduleNumber!,
                          sectionName: item.sectionName!,
                          allCompleted:
                              moduleAllCompleted[item.moduleNumber!] ?? false,
                          allPerfect:
                              moduleAllPerfect[item.moduleNumber!] ?? false,
                        ),
                      ));
                      dy += _bannerHeight;
                    } else {
                      final lesson = item.lesson!;
                      final x = width * _xFraction(lIdx) - _circleSize / 2;
                      widgets.add(Positioned(
                        top: dy + (_itemHeight - _circleSize) / 2,
                        left: x,
                        child: _LessonCircle(
                          lesson: lesson,
                          index: lIdx,
                          isPerfect: _isPerfect(lesson),
                          onRefresh: onRefresh,
                          isTutorialTarget:
                              tutorialTargetLessonId != null &&
                                  lesson.id == tutorialTargetLessonId,
                          onTutorialTargetTapped: onTutorialTargetTapped,
                        ),
                      ));
                      dy += _itemHeight;
                      lIdx++;
                    }
                    firstWidget = false;
                  }
                  return Stack(children: widgets);
                }),
              ],
            ),
          ),
        ),
        );
      },
    );
  }
}

class _RoadmapItem {
  final bool isBanner;
  final Lesson? lesson;
  final int? moduleNumber;
  final String? sectionName;

  const _RoadmapItem.banner(this.moduleNumber, this.sectionName)
      : isBanner = true,
        lesson = null;

  const _RoadmapItem.lesson(this.lesson)
      : isBanner = false,
        moduleNumber = null,
        sectionName = null;
}

class _RoadmapPainter extends CustomPainter {
  final List<Offset> positions;
  final List<bool> isCompleted;
  final List<bool> isPerfect;
  final List<int> moduleNumbers;

  const _RoadmapPainter({
    required this.positions,
    required this.isCompleted,
    required this.isPerfect,
    required this.moduleNumbers,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2) return;

    for (int i = 0; i < positions.length - 1; i++) {
      if (moduleNumbers[i] != moduleNumbers[i + 1]) continue;

      final p1 = positions[i];
      final p2 = positions[i + 1];

      // Gold path between two consecutive golden (perfect) lessons.
      final Color segmentColor;
      if (isPerfect[i] && isPerfect[i + 1]) {
        segmentColor = _kGold;
      } else if (isCompleted[i]) {
        segmentColor = _kGreen;
      } else {
        segmentColor = const Color(0xFFE5E5E5);
      }

      final paint = Paint()
        ..color = segmentColor
        ..strokeWidth = 14
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..cubicTo(
          p1.dx,
          p1.dy + (p2.dy - p1.dy) * 0.4,
          p2.dx,
          p1.dy + (p2.dy - p1.dy) * 0.6,
          p2.dx,
          p2.dy,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RoadmapPainter old) =>
      old.positions != positions ||
      old.isCompleted != isCompleted ||
      old.isPerfect != isPerfect ||
      old.moduleNumbers != moduleNumbers;
}

// ─── Section Banner ────────────────────────────────────────────────────────────

class _SectionBanner extends StatelessWidget {
  final int moduleNumber;
  final String sectionName;
  // All lessons in the module are completed (regardless of score).
  final bool allCompleted;
  // All lessons in the module are completed with a perfect score (golden).
  final bool allPerfect;

  const _SectionBanner({
    required this.moduleNumber,
    required this.sectionName,
    this.allCompleted = false,
    this.allPerfect = false,
  });

  @override
  Widget build(BuildContext context) {
    // Fully-golden module → gold/yellow banner. Otherwise the usual green.
    final LinearGradient gradient = allPerfect
        ? const LinearGradient(colors: [_kGold, _kGoldDark])
        : const LinearGradient(colors: [Color(0xFF58CC02), Color(0xFF45A800)]);

    // Trophy turns real gold once every lesson in the module is completed.
    final Color trophyColor =
        (allCompleted || allPerfect) ? const Color(0xFFFFE082) : Colors.white;

    return Container(
      height: 72,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(gradient: gradient),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Module $moduleNumber',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          TranslatedText(
            sectionName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Icon(Icons.emoji_events_rounded, color: trophyColor, size: 28),
        ],
      ),
    );
  }
}

// ─── Lesson Circle ─────────────────────────────────────────────────────────────

class _LessonCircle extends StatefulWidget {
  final Lesson lesson;
  final int index;
  // Lesson was completed with a perfect score → render golden (gold ring + bg).
  final bool isPerfect;
  final VoidCallback onRefresh;
  // True while the roadmap intro is pointing at this lesson (design doc
  // Item 16: gold highlight ring, distinct from the permanent green UI).
  final bool isTutorialTarget;
  // Called if this is the tutorial target and the user taps it directly
  // (the scrim's IgnorePointer lets the tap through) instead of using
  // Skip/Next — dismisses the intro so it doesn't reappear (/review fix).
  final VoidCallback? onTutorialTargetTapped;

  const _LessonCircle({
    required this.lesson,
    required this.index,
    required this.onRefresh,
    this.isPerfect = false,
    this.isTutorialTarget = false,
    this.onTutorialTargetTapped,
  });

  @override
  State<_LessonCircle> createState() => _LessonCircleState();
}

class _LessonCircleState extends State<_LessonCircle> {
  // Guards against a fast double-tap firing two overlapping _openLesson
  // calls, which would push two stacked LessonScreens (/review finding) —
  // same pattern as _isSubmitting in quiz_screen.dart and _buyingItem in
  // shop_screen.dart.
  bool _opening = false;

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final index = widget.index;
    final isPerfect = widget.isPerfect;
    final isTutorialTarget = widget.isTutorialTarget;
    final isCompleted = lesson.isCompleted;
    final isLocked = lesson.isLocked;

    Color outerColor;
    Color innerColor;
    Widget centerContent;

    if (isPerfect) {
      // Golden lesson: gold ring + gold background, but show the lesson number
      // (same as a regular completed circle) instead of a star icon.
      outerColor = _kGoldDark;
      innerColor = _kGold;
      centerContent = Text(
        '${index + 1}',
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    } else if (isCompleted) {
      outerColor = _kGreenDark;
      innerColor = _kGreen;
      centerContent = Text(
        '${index + 1}',
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    } else if (isLocked) {
      outerColor = const Color(0xFFE0E0E0);
      innerColor = const Color(0xFFEEEEEE);
      centerContent = Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '${index + 1}',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const Positioned(
            bottom: 0,
            right: 0,
            child: Icon(
              Icons.lock_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ],
      );
    } else {
      // Current / available
      outerColor = _kGreenDark;
      innerColor = _kGreen;
      centerContent = Text(
        '${index + 1}',
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }

    // Gold ring, distinct from the permanent green UI — design review Pass
    // 5, Item 16. Reuses the app's existing _kGold constant. Painted as a
    // border on the EXISTING 72x72 circle (not an additional padded wrapper)
    // so the widget's footprint never changes size — an earlier version
    // wrapped the circle in extra padded Containers, which grew it past the
    // parent's Positioned(top/left) calculation and visibly shifted the
    // highlighted circle ~4px off its computed anchor (/review finding).
    //
    // #FFC107 alone measures ~1.6:1 contrast against the roadmap's #F5F5F5
    // background — well under WCAG 1.4.11's 3:1 minimum for non-text UI
    // boundaries. The dark outline stroke gives it a real contrast boundary
    // against any background it can appear over, without changing the gold
    // "pay attention" identity.
    final Widget circle = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: outerColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: outerColor.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: isTutorialTarget
            ? Border.all(color: _kGold, width: 3)
                .add(Border.all(
                    color: Colors.black.withValues(alpha: 0.55), width: 1))
            : null,
      ),
      child: Center(
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: innerColor,
            shape: BoxShape.circle,
            border: isTutorialTarget
                ? Border.all(
                    color: Colors.black.withValues(alpha: 0.55), width: 1)
                : null,
          ),
          child: Center(child: centerContent),
        ),
      ),
    );

    Widget result = GestureDetector(
      onTap: isLocked
          ? () => _showLockedDialog(context)
          : () {
              // Tapping the highlighted target directly (the scrim lets
              // this through) counts as dismissing the intro — otherwise
              // the flag never gets set and it reappears every visit
              // (/review finding).
              if (isTutorialTarget) widget.onTutorialTargetTapped?.call();
              _openLesson(context);
            },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          circle,
          const SizedBox(height: 5),
          SizedBox(
            width: 90,
            child: TranslatedText(
              lesson.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isLocked ? _kGrey : const Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );

    if (isTutorialTarget) {
      // Screen reader parity for the visual highlight — design review Pass 6,
      // Issue 5. Same instruction sighted users get from Guide's message.
      // excludeSemantics: true replaces the descendant semantics (lesson
      // number + title) with this label instead of adding it alongside
      // them — without it, a screen reader announces both, which is
      // confusing, not parity (/review finding).
      result = Semantics(
        label: TranslationService.translate(context, 'guide_intro_1'),
        button: true,
        excludeSemantics: true,
        child: result,
      );
    }

    return result;
  }

  Future<void> _openLesson(BuildContext context) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final lesson = widget.lesson;
      final questions = await ApiService.fetchQuiz(lesson.id);
      lesson.questions = questions;
      if (context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LessonScreen(lesson: lesson),
          ),
        );
        widget.onRefresh();
      }
    } catch (e) {
      if (context.mounted) _showQuizLoadErrorDialog(context);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _showQuizLoadErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: _kGrey),
            const SizedBox(width: 8),
            Text(TranslationService.translate(context, 'quiz_load_error')),
          ],
        ),
        content: Text(
          TranslationService.translate(context, 'quiz_load_error_desc'),
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              TranslationService.translate(context, 'ok'),
              style: const TextStyle(color: _kGrey, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openLesson(context);
            },
            child: Text(
              TranslationService.translate(context, 'try_again'),
              style: const TextStyle(color: _kGreen, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showLockedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock_rounded, color: _kGrey),
            const SizedBox(width: 8),
            Text(TranslationService.translate(context, 'lesson_locked')),
          ],
        ),
        content: Text(
          TranslationService.translate(context, 'lesson_locked_desc'),
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              TranslationService.translate(context, 'ok'),
              style: const TextStyle(color: _kGreen, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

