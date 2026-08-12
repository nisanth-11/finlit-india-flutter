import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/main.dart';
import 'package:frontend/screens/settings_screen.dart';
import 'package:frontend/screens/registration_screen.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const FinLitApp(isRegistered: false));
    expect(find.text('FinLit India'), findsWidgets);
  });

  testWidgets('SettingsScreen displays radio buttons and allows selecting language', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'language': 'en'});
    
    await tester.pumpWidget(const FinLitApp(isRegistered: false));
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(RegistrationScreen));
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    // Verify settings screen title and language select text
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Select Language'), findsOneWidget);

    // Verify there are three radio boxes (using Radio type)
    expect(find.byType(Radio<String>), findsNWidgets(3));

    // Initially English radio should be selected
    final radiosBefore = tester.widgetList<Radio<String>>(find.byType(Radio<String>)).toList();
    expect(radiosBefore[0].value, 'en');
    expect(radiosBefore[1].value, 'hi');
    expect(radiosBefore[2].value, 'kn');
    expect(radiosBefore[0].groupValue, 'en');

    // Tap on the Hindi option text
    await tester.tap(find.text('हिन्दी (Hindi)'));
    // Await async futures (SharedPreferences etc)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Verify settings screen title changed to Hindi translation 'सेटिंग्स'
    expect(find.text('सेटिंग्स'), findsOneWidget);
    expect(find.text('भाषा चुनें'), findsOneWidget);

    // Verify the radio buttons groupValue is updated to 'hi'
    final radiosAfter = tester.widgetList<Radio<String>>(find.byType(Radio<String>)).toList();
    expect(radiosAfter[0].groupValue, 'hi');
  });
}
