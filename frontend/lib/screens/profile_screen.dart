import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/translations.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _phone = '';
  String? _userId;
  int _completedCount = 0;
  int _totalLessons = 0;
  bool _isLoading = true;

  // Shop / owned items. The owned counts live in the global shopItemsNotifier
  // so the "My Items" section can update live after a purchase.
  DateTime? _doubleCoinActiveUntil;
  bool _activatingDoubleCoin = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('display_name') ?? prefs.getString('phone') ?? 'Learner';
      final userId = prefs.getString('user_id');
      int completedCount = 0;
      int totalLessons = 0;
      int streak = 0;
      int coins = 0;
      int streakFreezeCount = 0;
      int doubleCoinCount = 0;
      int quizShieldCount = 0;
      DateTime? doubleCoinActiveUntil;
      if (userId != null) {
        final progress = await ApiService.fetchProgress(userId);
        completedCount = progress.where((p) => p['is_completed'] == true).length;
        final lessons = await ApiService.fetchLessons();
        totalLessons = lessons.length;
        final stats = await ApiService.getUserStats(userId);
        streak = stats['streak_count'] ?? 0;
        coins = stats['coins'] ?? 0;
        // Sync the global coin/streak balances so every listener stays up to date.
        coinsNotifier.value = coins;
        streakNotifier.value = streak;
        // Sync the completed-lessons count so the progress bar stays live.
        completedLessonsNotifier.value = completedCount;

        final shopItems = await ApiService.getShopItems(userId);
        streakFreezeCount = shopItems['streak_freeze_count'] ?? 0;
        doubleCoinCount = shopItems['double_coin_count'] ?? 0;
        quizShieldCount = shopItems['quiz_shield_count'] ?? 0;
        doubleCoinActiveUntil =
            _parseActiveUntil(shopItems['double_coin_active_until']);
        // Sync the owned-item counts so the "My Items" section stays live.
        shopItemsNotifier.value = {
          'streak_freeze_count': streakFreezeCount,
          'double_coin_count': doubleCoinCount,
          'quiz_shield_count': quizShieldCount,
        };
      }

      if (mounted) {
        setState(() {
          _phone = phone;
          _userId = userId;
          _completedCount = completedCount;
          _totalLessons = totalLessons;
          _doubleCoinActiveUntil = doubleCoinActiveUntil;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Parses the ISO double-coin expiry; returns null if absent or expired.
  DateTime? _parseActiveUntil(dynamic raw) {
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null || parsed.isBefore(DateTime.now())) return null;
    return parsed;
  }

  bool get _doubleCoinActive => _doubleCoinActiveUntil != null;

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _activateDoubleCoin() async {
    if (_userId == null || _activatingDoubleCoin) return;
    setState(() => _activatingDoubleCoin = true);
    final result = await ApiService.activateDoubleCoin(_userId!);
    if (!mounted) return;
    if (result.containsKey('error')) {
      setState(() => _activatingDoubleCoin = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'].toString())),
      );
      return;
    }
    // Decrement the owned Double Coin count via the global notifier so the
    // "My Items" section reflects the consumed item live.
    final currentDoubleCoin =
        shopItemsNotifier.value['double_coin_count'] ?? 0;
    shopItemsNotifier.value = {
      ...shopItemsNotifier.value,
      'double_coin_count': currentDoubleCoin > 0 ? currentDoubleCoin - 1 : 0,
    };
    setState(() {
      _doubleCoinActiveUntil = _parseActiveUntil(result['active_until']);
      _activatingDoubleCoin = false;
    });
  }

  // Dynamic status derived from the percentage of lessons completed out of the
  // total available lessons.
  ({IconData icon, String label}) _statusFor(int completed, int total) {
    final percent = total > 0 ? (completed / total) * 100 : 0;
    if (percent <= 0) return (icon: Icons.eco, label: 'Beginner');
    if (percent <= 40) return (icon: Icons.menu_book, label: 'Learner');
    if (percent <= 70) return (icon: Icons.explore, label: 'Explorer');
    if (percent < 100) return (icon: Icons.star, label: 'Expert');
    return (icon: Icons.emoji_events, label: 'Master');
  }

  // Owned shop items, shown below the progress bar. Driven by the global
  // notifier so the counts update live after a purchase.
  Widget _buildOwnedItemsSection(BuildContext context) {
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: shopItemsNotifier,
      builder: (context, items, _) {
        final streakFreezeCount = items['streak_freeze_count'] ?? 0;
        final doubleCoinCount = items['double_coin_count'] ?? 0;
        final quizShieldCount = items['quiz_shield_count'] ?? 0;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                TranslationService.translate(context, 'my_items'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
              _ownedItemRow(
                icon: Icons.ac_unit,
                iconColor: const Color(0xFF1CB0F6),
                label: TranslationService.translate(context, 'streak_freeze'),
                count: streakFreezeCount,
              ),
              const SizedBox(height: 10),
              _ownedItemRow(
                icon: Icons.double_arrow,
                iconColor: const Color(0xFFFFA000),
                label: TranslationService.translate(context, 'double_coin'),
                count: doubleCoinCount,
                trailing: _doubleCoinActive
                    ? Text(
                        '${TranslationService.translate(context, 'active_until')}: ${_formatDate(_doubleCoinActiveUntil!)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFA000),
                        ),
                      )
                    : (doubleCoinCount > 0
                        ? SizedBox(
                            height: 34,
                            child: ElevatedButton(
                              onPressed: _activatingDoubleCoin
                                  ? null
                                  : _activateDoubleCoin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFA000),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _activatingDoubleCoin
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(
                                      TranslationService.translate(
                                          context, 'activate'),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                    ),
                            ),
                          )
                        : null),
              ),
              const SizedBox(height: 10),
              _ownedItemRow(
                icon: Icons.shield,
                iconColor: const Color(0xFF58CC02),
                label: TranslationService.translate(context, 'quiz_shield'),
                count: quizShieldCount,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _ownedItemRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required int count,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
        Text(
          'x$count',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF666666),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing,
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final username = _phone;
    final completedCount = _completedCount;
    final totalLessons = _totalLessons;
    final status = _statusFor(completedCount, totalLessons);
    final completedLessons = []; // Placeholder to fix compilation error

    return SafeArea(
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    TranslationService.translate(context, 'my_profile'),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_rounded, color: Color(0xFF666666), size: 28),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    ).then((_) {
                      _loadProfile();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Avatar
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF58CC02), width: 3),
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 56,
                color: Color(0xFF58CC02),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              username,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            // Dynamic status based on lessons-completed percentage.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(status.icon, size: 20, color: const Color(0xFF58CC02)),
                const SizedBox(width: 6),
                Text(
                  status.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF58CC02),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Stats row — show a spinner while the profile data is loading
            // instead of flashing placeholder zeros.
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF58CC02)),
                ),
              )
            else ...[
              Row(
                children: [
                  // Streak card driven by the global notifier so it updates live
                  // after a quiz completion.
                  ValueListenableBuilder<int>(
                    valueListenable: streakNotifier,
                    builder: (context, liveStreak, _) => _StatCard(
                      icon: Icons.local_fire_department,
                      iconColor: Colors.orange,
                      label: TranslationService.translate(context, 'streak'),
                      value: '$liveStreak',
                      color: const Color(0xFFFFF3E0),
                      borderColor: const Color(0xFFFF9800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Coins card driven by the global notifier so it updates live
                  // after a quiz reward or shop purchase.
                  ValueListenableBuilder<int>(
                    valueListenable: coinsNotifier,
                    builder: (context, liveCoins, _) => _StatCard(
                      icon: Icons.monetization_on,
                      iconColor: Colors.amber,
                      label: TranslationService.translate(context, 'coins'),
                      value: '$liveCoins',
                      color: const Color(0xFFFFF9C4),
                      borderColor: const Color(0xFFFFD600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Progress bar: completed / total lessons. Driven by the global
              // notifier so it updates live after completing a lesson.
              ValueListenableBuilder<int>(
                valueListenable: completedLessonsNotifier,
                builder: (context, liveCompleted, _) {
                  final liveFraction =
                      totalLessons > 0 ? liveCompleted / totalLessons : 0.0;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF58CC02).withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$liveCompleted / $totalLessons ${TranslationService.translate(context, 'lessons_completed')}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: liveFraction,
                            backgroundColor: const Color(0xFFD7EAD0),
                            color: const Color(0xFF58CC02),
                            minHeight: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              _buildOwnedItemsSection(context),
            ],
            const SizedBox(height: 32),
            // Completed lessons list
            if (completedLessons.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  TranslationService.translate(context, 'lessons_title'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...completedLessons.map(
                (lesson) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF58CC02),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TranslatedText(
                                lesson.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              TranslatedText(
                                'Module ${lesson.moduleNumber} · ${lesson.sectionName}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF888888),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '+${lesson.coinsReward} 💰',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD4A017),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color color;
  final Color borderColor;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.color,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: borderColor.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF666666),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
