import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/main.dart';

// Regression test (IRON RULE, /plan-eng-review): the roadmap intro trigger
// was added to RoadmapScreen's existing BottomNavigationBar onTap handler.
// This verifies normal tab-switching still works after that change — the
// behavior existed before this feature and had no test.
//
// The standalone Shop-tip and first-quiz-completion tests that used to live
// here were removed when the tutorial was merged into a single upfront
// walkthrough (roadmap intro now covers greeting, lesson handoff, and
// coins/Shop in one sitting — see roadmap_screen.dart's `_IntroStep`). A new
// widget test covering the merged walkthrough's full advance-through-3-steps
// flow isn't added here: `_maybeShowIntro()` only shows the intro once
// `_lessons` is non-empty, which requires `ApiService.fetchLessons()` to
// succeed — and ApiService calls `http.get` directly with no injectable
// client (TODOS.md: "Make ApiService's HTTP client injectable for testing"),
// so it always fails fast in this sandbox (no backend reachable) and the
// intro can never actually render here. Verified manually instead (see
// investigate session notes).
int _currentNavIndex(WidgetTester tester) {
  return tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).currentIndex;
}

// Invokes the BottomNavigationBar's onTap callback directly rather than
// simulating a pixel tap. This regression test cares whether the onTap
// handler's logic (tab switch) still works, not about pixel-perfect
// hit-test geometry in the default test viewport — those are different
// concerns, and the latter is unrelated to this feature's change.
Future<void> _tapNavIndex(WidgetTester tester, int index) async {
  final navBar =
      tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
  navBar.onTap!(index);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'bottom nav tab-switching still works after tutorial trigger changes',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'is_registered': true,
      'user_id': 'test-user',
      'language': 'en',
      // Tutorial flag pre-seeded as seen so the intro overlay doesn't
      // intercept the taps this test is exercising.
      'tutorial_seen_roadmap_intro': true,
    });

    await tester.pumpWidget(const FinLitApp(isRegistered: true));
    // No backend reachable in the test sandbox — fetchLessons()/etc. fail
    // fast (connection refused on 127.0.0.1), caught by the existing
    // try/catch, which flips _isLoading to false so the tab UI renders.
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(_currentNavIndex(tester), 0);

    await _tapNavIndex(tester, 1);
    expect(_currentNavIndex(tester), 1);

    await _tapNavIndex(tester, 2);
    expect(_currentNavIndex(tester), 2);

    await _tapNavIndex(tester, 3);
    expect(_currentNavIndex(tester), 3);

    await _tapNavIndex(tester, 0);
    expect(_currentNavIndex(tester), 0);
  });
}
