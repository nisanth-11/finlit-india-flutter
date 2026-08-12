import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/screens/profile_screen.dart';

// Regression test for the /review-surfaced ProfileScreen bug fix:
// _loadProfile had no try/catch around its API calls, unlike every other
// data-loading method in this codebase, so an unreachable backend (the
// normal test-sandbox state whenever user_id is set) threw uncaught and
// left the screen spinning on CircularProgressIndicator forever.
void main() {
  testWidgets(
      'ProfileScreen recovers from an unreachable backend instead of spinning forever',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'user_id': 'test-user',
      'display_name': 'Tester',
    });

    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    // No backend reachable in the sandbox -> ApiService.fetchProgress
    // (the first call once userId != null) throws, aborting the try block
    // before _phone ever gets set. The fix's job is only to stop the
    // spinner, not to preserve locally-known display_name on failure —
    // that's consistent with how _HomeTabState._loadData's catch behaves
    // too (stop loading, don't preserve partial local state).
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
