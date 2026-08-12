import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../services/translations.dart';
import 'roadmap_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;
  String? _nameErrorText;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    print('=== _onContinue triggered with phone: $phone, name: $name ===');
    bool hasError = false;
    if (name.isEmpty) {
      setState(() => _nameErrorText = TranslationService.translate(context, 'name_hint'));
      hasError = true;
    }
    if (phone.length < 10) {
      setState(() => _errorText = TranslationService.translate(context, 'phone_error'));
      hasError = true;
    }
    if (hasError) return;
    setState(() {
      _isLoading = true;
      _errorText = null;
      _nameErrorText = null;
    });

    try {
      var response = await ApiService.registerUser(phone);
      print('=== _onContinue response: $response ===');
      if (!response.containsKey('user_id') &&
          response['detail'] == 'User exists') {
        // Phone already has an account — recover it via login instead of
        // getting stuck. Previously this just showed an error, leaving
        // returning users unable to get back into an account they already
        // had (and, before that fix, silently proceeding with no user_id at
        // all, which disabled lesson locking and coin rewards).
        response = await ApiService.loginUser(phone);
      }
      if (!response.containsKey('user_id')) {
        // Neither register nor login (if attempted) returned a user_id — do
        // NOT mark is_registered or proceed, otherwise the app navigates to
        // RoadmapScreen with no user_id ever persisted, which silently
        // disables lesson locking and coin rewards (both are gated on
        // user_id != null downstream).
        setState(() {
          _errorText = 'Error: Failed to register. Check connection.';
        });
        return;
      }

      final userId = response['user_id'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_registered', true);
      await prefs.setString('phone', phone);
      await prefs.setString('display_name', name);
      await prefs.setString('user_id', userId);
      final language = prefs.getString('language') ?? 'en';
      await ApiService.updateProfile(userId, name, language);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RoadmapScreen()),
      );
    } catch (e, stack) {
      print('=== _onContinue EXCEPTION: $e ===');
      print(stack);
      setState(() => _errorText = 'Error: Failed to register. Check connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Logo / Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF58CC02),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.savings_rounded, color: Colors.white, size: 56),
              ),
              const SizedBox(height: 28),
              const Text(
                'FinLit India',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                TranslationService.translate(context, 'phone_info') == 'phone_info'
                    ? 'Learn smart money habits\none step at a time'
                    : TranslationService.translate(context, 'phone_info').replaceAll(RegExp(r'\\n'), '\n'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  color: Color(0xFF777777),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 56),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  TranslationService.translate(context, 'your_name'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: 'nameField',
                child: TextField(
                  key: const Key('nameField'),
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    hintText: TranslationService.translate(context, 'name_hint'),
                    hintStyle: const TextStyle(color: Color(0xFFCCCCCC)),
                    errorText: _nameErrorText,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    filled: true,
                    fillColor: const Color(0xFFF7F7F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF58CC02), width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                  onChanged: (_) {
                    if (_nameErrorText != null) setState(() => _nameErrorText = null);
                  },
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  TranslationService.translate(context, 'enter_phone'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: 'phoneField',
                child: TextField(
                  key: const Key('phoneField'),
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: const TextStyle(fontSize: 20, letterSpacing: 2),
                  decoration: InputDecoration(
                    hintText: '98765 43210',
                    hintStyle: const TextStyle(color: Color(0xFFCCCCCC), letterSpacing: 2),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 16, right: 8),
                      child: Text('+91 ', style: TextStyle(fontSize: 18, color: Color(0xFF555555))),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    errorText: _errorText,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    filled: true,
                    fillColor: const Color(0xFFF7F7F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF58CC02), width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                  onChanged: (_) {
                    if (_errorText != null) setState(() => _errorText = null);
                  },
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: Semantics(
                  label: 'continueButton',
                  button: true,
                  child: ElevatedButton(
                    key: const Key('continueButton'),
                    onPressed: _isLoading ? null : _onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF58CC02),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFB8E986),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 3,
                      shadowColor: const Color(0xFF58CC02).withValues(alpha: 0.4),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Text(
                            TranslationService.translate(context, 'continue_btn'),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                TranslationService.translate(context, 'phone_info') == 'phone_info'
                    ? 'Your phone number will only be used\nto save your progress.'
                    : TranslationService.translate(context, 'phone_info').replaceAll(RegExp(r'\\n'), '\n'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA), height: 1.5),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
