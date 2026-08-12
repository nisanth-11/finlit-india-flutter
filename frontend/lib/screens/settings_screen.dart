import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/translations.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  bool _isEditingName = false;
  bool _isSaving = false;
  String _currentName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('display_name') ?? prefs.getString('phone') ?? '';

    if (mounted) {
      setState(() {
        _currentName = name;
        _nameController.text = name;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('display_name', newName);

    final userId = prefs.getString('user_id');
    final lang = prefs.getString('language') ?? 'en';
    if (userId != null) {
      await ApiService.updateProfile(userId, newName, lang);
    }

    if (mounted) {
      setState(() {
        _currentName = newName;
        _isEditingName = false;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(TranslationService.translate(context, 'save_success')),
          backgroundColor: const Color(0xFF58CC02),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A1A),
        ),
      ),
    );
  }

  Widget _buildNameSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: Color(0xFF58CC02), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _isEditingName
                ? TextField(
                    controller: _nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: TranslationService.translate(context, 'name_hint'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF58CC02)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF58CC02), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 16),
                    onSubmitted: (_) => _saveName(),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentName.isEmpty ? '—' : _currentName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        TranslationService.translate(context, 'your_name'),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 8),
          if (_isEditingName)
            _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF58CC02),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => setState(() {
                          _isEditingName = false;
                          _nameController.text = _currentName;
                        }),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('✕', style: TextStyle(color: Color(0xFF888888), fontSize: 16)),
                      ),
                      ElevatedButton(
                        onPressed: _saveName,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF58CC02),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(TranslationService.translate(context, 'save')),
                      ),
                    ],
                  )
          else
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Color(0xFF58CC02), size: 22),
              onPressed: () => setState(() => _isEditingName = true),
            ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard(
    BuildContext context, {
    required String code,
    required String name,
    required String flagEmoji,
    required String currentCode,
  }) {
    final isSelected = currentCode == code;

    return GestureDetector(
      onTap: () async {
        final provider = LanguageProvider.of(context);
        if (provider != null) {
          await provider.appState.changeLanguage(code);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF58CC02) : const Color(0xFFE0E0E0),
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF58CC02).withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(flagEmoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? const Color(0xFF2E7D32) : const Color(0xFF333333),
                ),
              ),
            ),
            Radio<String>(
              value: code,
              groupValue: currentCode,
              activeColor: const Color(0xFF58CC02),
              onChanged: (String? val) async {
                if (val != null) {
                  final provider = LanguageProvider.of(context);
                  if (provider != null) {
                    await provider.appState.changeLanguage(val);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = LanguageProvider.of(context);
    final currentLang = provider?.languageCode ?? 'en';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          TranslationService.translate(context, 'settings'),
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE0E0E0)),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF58CC02)),
            )
          : ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionHeader(
                      TranslationService.translate(context, 'edit_name'),
                    ),
                    _buildNameSection(context),
                    const SizedBox(height: 28),
                    _buildSectionHeader(
                      TranslationService.translate(context, 'select_language'),
                    ),
                    _buildLanguageCard(
                      context,
                      code: 'en',
                      name: 'English',
                      flagEmoji: '🇬🇧',
                      currentCode: currentLang,
                    ),
                    _buildLanguageCard(
                      context,
                      code: 'hi',
                      name: 'हिन्दी (Hindi)',
                      flagEmoji: '🇮🇳',
                      currentCode: currentLang,
                    ),
                    _buildLanguageCard(
                      context,
                      code: 'kn',
                      name: 'ಕನ್ನಡ (Kannada)',
                      flagEmoji: '🇮🇳',
                      currentCode: currentLang,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
