import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/translations.dart';
class BudgetScreen extends StatefulWidget {
  final bool isActive;
  const BudgetScreen({super.key, this.isActive = false});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final TextEditingController _incomeController = TextEditingController();

  final Map<String, TextEditingController> _categoryControllers = {};

  double _totalIncome = 0.0;

  Set<String> _selectedNeeds = {};
  Set<String> _selectedWants = {};

  final List<String> _availableNeeds = [
    'Food & Groceries',
    'Children\'s Education',
    'Loan Repayments',
    'Healthcare & Medicine',
    'Savings',
  ];

  final List<String> _availableWants = [
    'Snacks',
    'Jewelry',
    'Entertainment',
    'Clothes',
  ];

  void _updateCategoryControllers() {
    final allSelected = {..._selectedNeeds, ..._selectedWants};
    _categoryControllers.removeWhere((key, _) => !allSelected.contains(key));
    for (var item in allSelected) {
      if (!_categoryControllers.containsKey(item)) {
        final controller = TextEditingController();
        controller.addListener(() {
          setState(() {});
        });
        _categoryControllers[item] = controller;
      }
    }
  }

  @override
  void didUpdateWidget(covariant BudgetScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showNeedsWantsDialog(context);
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkLessonCompletion();
  }

  // Verify if Lesson 2 is completed; if not, show a blocking dialog
  Future<void> _checkLessonCompletion() async {
    final prefs = await SharedPreferences.getInstance();
    final completedLessons = prefs.getInt('completed_lessons') ?? 0;
    if (completedLessons < 2) {
      // Show dialog informing the user to complete Lesson 2 first
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              TranslationService.translate(context, 'budget_locked'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              TranslationService.translate(context, 'budget_locked_desc'),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: Text(
                  TranslationService.translate(context, 'ok'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      });
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    final needsList = prefs.getStringList('budget_needs') ?? [];
    final wantsList = prefs.getStringList('budget_wants') ?? [];
    _selectedNeeds = needsList.toSet();
    _selectedWants = wantsList.toSet();
    _updateCategoryControllers();

    final userId = prefs.getString('user_id') ?? 'test_user_123';

    if (userId.isNotEmpty) {
      try {
        final data = await ApiService.getBudget(userId);

        if (data != null) {
          _incomeController.text = (data['totalIncome'] ?? 0.0).toStringAsFixed(0);
          _totalIncome = (data['totalIncome'] ?? 0.0).toDouble();

          _categoryControllers.forEach((key, controller) {
            final lowerKey = key.toLowerCase();
            if (lowerKey.contains('food') || lowerKey.contains('groceries') || lowerKey.contains('snacks')) {
              controller.text = (data['food'] ?? 0.0).toStringAsFixed(0);
            } else if (lowerKey.contains('rent') || lowerKey.contains('clothes') || lowerKey.contains('jewelry')) {
              controller.text = (data['rent'] ?? 0.0).toStringAsFixed(0);
            } else if (lowerKey.contains('education') || lowerKey.contains('entertainment')) {
              controller.text = (data['education'] ?? 0.0).toStringAsFixed(0);
            } else if (lowerKey.contains('transport') || lowerKey.contains('smartphone')) {
              controller.text = (data['transport'] ?? 0.0).toStringAsFixed(0);
            } else if (lowerKey.contains('savings') || lowerKey.contains('loans') || lowerKey.contains('healthcare')) {
              controller.text = (data['savings'] ?? 0.0).toStringAsFixed(0);
            }
          });
          setState(() {});
          return; // Skip local load
        }
      } catch (e) {
        print('Error loading from API: $e');
      }
    }

    final income = prefs.getDouble('budget_income') ?? 0.0;
    if (income > 0) {
      _incomeController.text = income.toStringAsFixed(0);
      _totalIncome = income;

      for (var entry in _categoryControllers.entries) {
        final savedVal = prefs.getDouble('budget_amount_${entry.key}') ?? 0.0;
        if (savedVal > 0) {
          entry.value.text = savedVal.toStringAsFixed(0);
        }
      }
      setState(() {});
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save Locally
    await prefs.setDouble('budget_income', _totalIncome);
    await prefs.setStringList('budget_needs', _selectedNeeds.toList());
    await prefs.setStringList('budget_wants', _selectedWants.toList());
    
    for (var entry in _categoryControllers.entries) {
      final val = double.tryParse(entry.value.text) ?? 0.0;
      await prefs.setDouble('budget_amount_${entry.key}', val);
    }

    // Save to Backend API
    final userId = prefs.getString('user_id') ?? 'test_user_123';
    if (userId.isNotEmpty) {
      try {
        double getAmountForKeyword(List<String> keywords) {
          double total = 0.0;
          _categoryControllers.forEach((key, controller) {
            final lowerKey = key.toLowerCase();
            if (keywords.any((kw) => lowerKey.contains(kw))) {
              total += double.tryParse(controller.text) ?? 0.0;
            }
          });
          return total;
        }

        final foodVal = getAmountForKeyword(['food', 'groceries', 'snacks']);
        final rentVal = getAmountForKeyword(['rent', 'clothes', 'jewelry']);
        final educationVal = getAmountForKeyword(['education', 'entertainment']);
        final transportVal = getAmountForKeyword(['transport', 'smartphone']);
        final savingsVal = getAmountForKeyword(['savings', 'loans', 'healthcare']);

        await ApiService.saveBudget({
          'user_id': userId,
          'totalIncome': _totalIncome,
          'food': foodVal,
          'rent': rentVal,
          'education': educationVal,
          'transport': transportVal,
          'savings': savingsVal,
        });
      } catch (e) {
        print('API save error: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Budget saved successfully!'),
          backgroundColor: const Color(0xFF58CC02),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _resetData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('budget_income');
    await prefs.remove('budget_needs');
    await prefs.remove('budget_wants');
    for (var key in _categoryControllers.keys) {
      await prefs.remove('budget_amount_$key');
    }

    // Reset API data
    final userId = prefs.getString('user_id') ?? 'test_user_123';
    if (userId.isNotEmpty) {
      try {
        await ApiService.saveBudget({
          'user_id': userId,
          'totalIncome': 0.0,
          'food': 0.0,
          'rent': 0.0,
          'education': 0.0,
          'transport': 0.0,
          'savings': 0.0,
        });
      } catch (e) {
        print('API reset error: $e');
      }
    }

    _incomeController.clear();
    _categoryControllers.clear();
    _selectedNeeds.clear();
    _selectedWants.clear();
    setState(() {
      _totalIncome = 0.0;
    });
  }  double get _totalAllocated {
    double total = 0;
    for (var controller in _categoryControllers.values) {
      total += double.tryParse(controller.text) ?? 0.0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    List<Color> categoryColors = [
      const Color(0xFF58CC02),
      const Color(0xFF1CB0F6),
      const Color(0xFFFF9800),
      const Color(0xFFCE82FF),
      const Color(0xFFFF4B4B),
    ];

    final Map<String, String> sampleAmounts = {
      'Food': '3000',
      'Rent': '4500',
      'Education': '2250',
      'Transport': '2250',
      'Savings': '3000',
    };

    return SafeArea(
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.account_balance_wallet,
                    color: Color(0xFF58CC02),
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      TranslationService.translate(context, 'budget_management'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 32),

              // Income Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _incomeController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: TranslationService.translate(context, 'monthly_income'),
                        hintText: 'e.g. 15000',
                        hintStyle: const TextStyle(color: Color(0xFFCCCCCC)),
                        prefixIcon: const Icon(
                          Icons.currency_rupee_rounded,
                          color: Color(0xFF58CC02),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF58CC02),
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _totalIncome = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),

                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Categories Section
              Text(
                TranslationService.translate(context, 'categories'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Column(
                  children: [
                    ..._categoryControllers.entries
                        .toList()
                        .asMap()
                        .entries
                        .map((mapEntry) {
                          int index = mapEntry.key;
                          var entry = mapEntry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color:
                                        categoryColors[index %
                                            categoryColors.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    TranslationService.translate(context, entry.key.toLowerCase()),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: entry.value,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.right,
                                    decoration: InputDecoration(
                                      prefixText: '₹ ',
                                      hintText: 'e.g. ${sampleAmounts[entry.key] ?? '1500'}',
                                      hintStyle: const TextStyle(color: Color(0xFFCCCCCC)),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF58CC02),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    onChanged: (value) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Summary Section
              Text(
                TranslationService.translate(context, 'summary'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF58CC02), width: 2),
                ),
                child: Column(
                  children: [
                    _SummaryRow(
                      label: TranslationService.translate(context, 'total_income'),
                      value: '₹${_totalIncome.toStringAsFixed(0)}',
                    ),
                    const SizedBox(height: 12),
                    _SummaryRow(
                      label: TranslationService.translate(context, 'total_allocated'),
                      value: '₹${_totalAllocated.toStringAsFixed(0)}',
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFF58CC02),
                      ),
                    ),
                    _SummaryRow(
                      label: TranslationService.translate(context, 'remaining_balance'),
                      value:
                          '₹${(_totalIncome - _totalAllocated).toStringAsFixed(0)}',
                      isBold: true,
                    ),
                    if (_totalAllocated > _totalIncome)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          TranslationService.translate(context, 'budget_exceeds'),
                          style: const TextStyle(
                            color: Color(0xFFFF4B4B),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Needs & Wants Section
              Text(
                TranslationService.translate(context, 'needs_and_wants'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),
              _buildNeedsAndWantsCard(context),
              const SizedBox(height: 24),

              // Suggested 50/30/20 Budget Section
              if (_totalIncome > 0) ...[
                Text(
                  TranslationService.translate(context, 'suggested_breakdown'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        TranslationService.translate(context, 'suggested_desc'),
                        style: const TextStyle(color: Color(0xFF666666), fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      ...() {
                        final List<Widget> list = [];
                        final needsCount = _selectedNeeds.length;
                        final wantsCount = _selectedWants.length;

                        if (needsCount > 0) {
                          final pct = 50 / needsCount;
                          final amount = _totalIncome * 0.50 / needsCount;
                          for (var need in _selectedNeeds) {
                            list.add(
                              _SummaryRow(
                                label: '${TranslationService.translate(context, need.toLowerCase())} (${pct.toStringAsFixed(0)}%)',
                                value: '₹${amount.toStringAsFixed(0)}',
                              ),
                            );
                            list.add(const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(color: Color(0xFFF0F0F0)),
                            ));
                          }
                        }

                        if (wantsCount > 0) {
                          final pct = 30 / wantsCount;
                          final amount = _totalIncome * 0.30 / wantsCount;
                          for (var want in _selectedWants) {
                            list.add(
                              _SummaryRow(
                                label: '${TranslationService.translate(context, want.toLowerCase())} (${pct.toStringAsFixed(0)}%)',
                                value: '₹${amount.toStringAsFixed(0)}',
                              ),
                            );
                            list.add(const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(color: Color(0xFFF0F0F0)),
                            ));
                          }
                        }

                        list.add(
                          _SummaryRow(
                            label: '${TranslationService.translate(context, 'savings')} (20%)',
                            value: '₹${(_totalIncome * 0.20).toStringAsFixed(0)}',
                          ),
                        );
                        
                        return list;
                      }(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetData,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(
                          color: Color(0xFFAFAFAF),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        TranslationService.translate(context, 'reset_budget'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1CB0F6),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        TranslationService.translate(context, 'save_budget'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showNeedsWantsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                TranslationService.translate(context, 'plan_needs_wants'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            TranslationService.translate(context, 'needs'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                        ..._availableNeeds.map((needKey) {
                          final isChecked = _selectedNeeds.contains(needKey);
                          return CheckboxListTile(
                            activeColor: const Color(0xFF58CC02),
                            value: isChecked,
                            title: Text(TranslationService.translate(context, needKey.toLowerCase())),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (val) {
                              setDialogState(() {
                                if (val == true) {
                                  _selectedNeeds.add(needKey);
                                } else {
                                  _selectedNeeds.remove(needKey);
                                }
                              });
                            },
                          );
                        }),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            TranslationService.translate(context, 'wants'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ),
                        ..._availableWants.map((wantKey) {
                          final isChecked = _selectedWants.contains(wantKey);
                          return CheckboxListTile(
                            activeColor: const Color(0xFFFF9800),
                            value: isChecked,
                            title: Text(TranslationService.translate(context, wantKey.toLowerCase())),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (val) {
                              setDialogState(() {
                                if (val == true) {
                                  _selectedWants.add(wantKey);
                                } else {
                                  _selectedWants.remove(wantKey);
                                }
                              });
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _updateCategoryControllers();
                      setState(() {});
                      _saveData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF58CC02),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      TranslationService.translate(context, 'save_selections'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNeedsAndWantsCard(BuildContext context) {
    final hasNeeds = _selectedNeeds.isNotEmpty;
    final hasWants = _selectedWants.isNotEmpty;

    if (!hasNeeds && !hasWants) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Column(
          children: [

            const SizedBox(height: 12),
            Text(
              TranslationService.translate(context, 'identify_needs_wants_desc'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF666666), height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _showNeedsWantsDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF58CC02),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                TranslationService.translate(context, 'plan_needs_wants'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TranslationService.translate(context, 'needs'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (!hasNeeds)
                      const Text('—', style: TextStyle(color: Colors.grey))
                    else
                      ..._selectedNeeds.map((needKey) => Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('🟢 ', style: TextStyle(fontSize: 12)),
                                Expanded(
                                  child: Text(
                                    TranslationService.translate(context, needKey.toLowerCase()),
                                    style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
                                  ),
                                ),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TranslationService.translate(context, 'wants'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE65100),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (!hasWants)
                      const Text('—', style: TextStyle(color: Colors.grey))
                    else
                      ..._selectedWants.map((wantKey) => Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('🟠 ', style: TextStyle(fontSize: 12)),
                                Expanded(
                                  child: Text(
                                    TranslationService.translate(context, wantKey.toLowerCase()),
                                    style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
                                  ),
                                ),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => _showNeedsWantsDialog(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF58CC02), width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              TranslationService.translate(context, 'plan_needs_wants'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF58CC02),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 18 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? const Color(0xFF1A1A1A) : const Color(0xFF444444),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 18 : 16,
            fontWeight: FontWeight.bold,
            color: isBold ? const Color(0xFF1A1A1A) : const Color(0xFF58CC02),
          ),
        ),
      ],
    );
  }
}