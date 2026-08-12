import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (tester.any(finder)) return;
  }
  expect(finder, findsOneWidget);
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await waitFor(tester, finder);
  await tester.tap(finder);
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('user can complete the main app flow', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final phone = '9${DateTime.now().millisecondsSinceEpoch.toString().substring(4, 13)}';

    app.main();
    await waitFor(tester, find.text('Enter your phone number'));

    await tester.enterText(find.byKey(const Key('phoneField')), phone);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    
    await tester.ensureVisible(find.byKey(const Key('continueButton')));
    await tester.pump(const Duration(seconds: 2));
    await tap(tester, find.byKey(const Key('continueButton')));

    await tap(tester, find.text('What is a Budget?'));

    await waitFor(tester, find.text('Choose your response'));

    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 500));

      if (tester.any(find.textContaining('Start Quiz'))) {
        break;
      }

      final header = find.text('Choose your response');
      if (tester.any(header)) {
        final panel = find.ancestor(of: header, matching: find.byType(Column));
        final option = find.descendant(of: panel, matching: find.byType(GestureDetector)).first;
        if (tester.any(option)) {
          await tester.tap(option);
          await tester.pump(const Duration(seconds: 2));
        }
      }
    }

    await tap(tester, find.textContaining('Start Quiz'));
    await waitFor(tester, find.textContaining('Q1.'));

    for (var q = 0; q < 3; q++) {
      await tap(tester, find.text('A'));
      await tap(tester, find.text('Check Answer'));

      if (q == 2) {
        await tap(tester, find.text('Finish Quiz'));
      } else {
        await tap(tester, find.text('Continue'));
      }
    }

    await tap(tester, find.text('Back to Roadmap'));
    await waitFor(tester, find.text('FinLit India'));

    await tap(tester, find.byIcon(Icons.account_balance_wallet_outlined));
    await waitFor(tester, find.text('Budget Management'));
    expect(find.textContaining('Monthly Income'), findsOneWidget);

    await tap(tester, find.byIcon(Icons.person_outline_rounded));
    await waitFor(tester, find.text('My Profile'));
    expect(find.text(phone), findsOneWidget);
    expect(find.text('Lessons Completed'), findsOneWidget);

    await tap(tester, find.byIcon(Icons.home_outlined));
    await waitFor(tester, find.text('FinLit India'));
  });
}
