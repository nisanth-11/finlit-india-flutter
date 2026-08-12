import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/translations.dart';

const _kGreen = Color(0xFF58CC02);

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String? _userId;
  int _coins = 0;
  bool _isLoading = true;
  // The item currently being purchased (so its button can show a spinner).
  String? _buyingItem;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    int coins = 0;
    if (userId != null) {
      final stats = await ApiService.getUserStats(userId);
      coins = stats['coins'] ?? 0;
    }
    // Keep the global notifier in sync so the header reflects the latest total.
    coinsNotifier.value = coins;
    if (mounted) {
      setState(() {
        _userId = userId;
        _coins = coins;
        _isLoading = false;
      });
    }
  }

  Future<void> _buy(String item, String title) async {
    if (_userId == null || _buyingItem != null) return;
    setState(() => _buyingItem = item);

    final result = await ApiService.buyItem(_userId!, item);

    if (!mounted) return;
    setState(() => _buyingItem = null);

    if (result.containsKey('error')) {
      final isNotEnough = result['error'] == 'Not enough coins';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isNotEnough ? 'Not enough coins 💸' : result['error']),
          backgroundColor: const Color(0xFFFF4B4B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // Update the coin balance shown in the top bar from the server response.
    final remaining = result['remaining_coins'] ?? _coins;
    coinsNotifier.value = remaining;
    setState(() => _coins = remaining);

    // Fetch the updated owned-item counts so the profile "My Items" section
    // refreshes live via shopItemsNotifier.
    final shopItems = await ApiService.getShopItems(_userId!);
    shopItemsNotifier.value = {
      'streak_freeze_count': shopItems['streak_freeze_count'] ?? 0,
      'double_coin_count': shopItems['double_coin_count'] ?? 0,
      'quiz_shield_count': shopItems['quiz_shield_count'] ?? 0,
    };
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Purchased!'),
        backgroundColor: _kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Top bar with the live coin balance.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    TranslationService.translate(context, 'shop'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9C4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on,
                          size: 18, color: Colors.amber),
                      const SizedBox(width: 4),
                      ValueListenableBuilder<int>(
                        valueListenable: coinsNotifier,
                        builder: (context, coins, _) => Text(
                          '$coins',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                TranslationService.translate(context, 'spend_coins'),
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _kGreen))
                : ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context)
                        .copyWith(overscroll: false),
                    child: ListView(
                    // ClampingScrollPhysics prevents the list from stretching
                    // when scrolled past the top/bottom edge.
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _ShopItem(
                        icon: Icons.ac_unit,
                        iconColor: const Color(0xFF1CB0F6),
                        title: TranslationService.translate(
                            context, 'streak_freeze'),
                        description: TranslationService.translate(
                            context, 'streak_freeze_desc'),
                        price: 200,
                        isBuying: _buyingItem == 'streak_freeze',
                        onBuy: () => _buy(
                            'streak_freeze',
                            TranslationService.translate(
                                context, 'streak_freeze')),
                      ),
                      const SizedBox(height: 16),
                      _ShopItem(
                        icon: Icons.double_arrow,
                        iconColor: const Color(0xFFFFA000),
                        title: TranslationService.translate(
                            context, 'double_coin'),
                        description: TranslationService.translate(
                            context, 'double_coin_desc'),
                        price: 50,
                        isBuying: _buyingItem == 'double_coin',
                        onBuy: () => _buy(
                            'double_coin',
                            TranslationService.translate(
                                context, 'double_coin')),
                      ),
                      const SizedBox(height: 16),
                      _ShopItem(
                        icon: Icons.shield,
                        iconColor: const Color(0xFF58CC02),
                        title: TranslationService.translate(
                            context, 'quiz_shield'),
                        description: TranslationService.translate(
                            context, 'quiz_shield_desc'),
                        price: 100,
                        isBuying: _buyingItem == 'quiz_shield',
                        onBuy: () => _buy(
                            'quiz_shield',
                            TranslationService.translate(
                                context, 'quiz_shield')),
                      ),
                    ],
                  ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ShopItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final int price;
  final bool isBuying;
  final VoidCallback onBuy;

  const _ShopItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.price,
    required this.isBuying,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 40, color: iconColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: isBuying ? null : onBuy,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _kGreen,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: _kGreen, width: 2),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: isBuying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _kGreen),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on,
                          size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '$price',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
