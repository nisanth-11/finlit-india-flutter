import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/registration_screen.dart';
import 'screens/roadmap_screen.dart';
import 'services/translations.dart';

/// Global coin balance. Updated whenever coins change (quiz reward, shop
/// purchase) so the top bar, shop header and profile card can refresh via a
/// [ValueListenableBuilder] without reloading the whole screen.
final ValueNotifier<int> coinsNotifier = ValueNotifier<int>(0);

/// Global streak counter. Updated whenever the streak changes (e.g. after
/// completing a quiz) so the top bar and profile card can refresh via a
/// [ValueListenableBuilder] without reloading the whole screen.
final ValueNotifier<int> streakNotifier = ValueNotifier<int>(0);

/// Global owned shop item counts. Updated after a purchase (shop screen) so the
/// profile "My Items" section can refresh live via a [ValueListenableBuilder]
/// without reloading the whole screen.
final ValueNotifier<Map<String, int>> shopItemsNotifier =
    ValueNotifier<Map<String, int>>({
  'streak_freeze_count': 0,
  'double_coin_count': 0,
  'quiz_shield_count': 0,
});

/// Global completed-lessons count. Updated after completing a lesson (quiz
/// screen) so the profile progress bar can refresh live via a
/// [ValueListenableBuilder] without reloading the whole screen.
final ValueNotifier<int> completedLessonsNotifier = ValueNotifier<int>(0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool isRegistered = (prefs.getBool('is_registered') ?? false) &&
      prefs.getString('user_id') != null;
  runApp(FinLitApp(isRegistered: isRegistered));
}

class FinLitApp extends StatefulWidget {
  final bool isRegistered;

  const FinLitApp({super.key, required this.isRegistered});

  @override
  State<FinLitApp> createState() => FinLitAppState();

  static FinLitAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<FinLitAppState>();
}

class FinLitAppState extends State<FinLitApp> {
  String _languageCode = 'en';

  String get languageCode => _languageCode;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _languageCode = prefs.getString('language') ?? 'en';
    });
  }

  Future<void> changeLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', code);
    setState(() {
      _languageCode = code;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LanguageProvider(
      languageCode: _languageCode,
      appState: this,
      child: MaterialApp(
        title: 'FinLit India',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF58CC02),
            primary: const Color(0xFF58CC02),
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        home: widget.isRegistered
            ? RoadmapScreen(key: ValueKey(_languageCode))
            : RegistrationScreen(key: ValueKey(_languageCode)),
      ),
    );
  }
}
