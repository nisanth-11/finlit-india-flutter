import 'package:flutter/material.dart';
import 'package:translator/translator.dart';
import '../main.dart';

class LanguageProvider extends InheritedWidget {
  final String languageCode;
  final FinLitAppState appState;

  const LanguageProvider({
    super.key,
    required this.languageCode,
    required this.appState,
    required super.child,
  });

  static LanguageProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LanguageProvider>();
  }

  @override
  bool updateShouldNotify(LanguageProvider oldWidget) {
    return languageCode != oldWidget.languageCode;
  }
}

class TranslationService {
  // Static dictionary for key UI labels to avoid latency for basic navigation elements
  static const Map<String, Map<String, String>> staticTranslations = {
    'en': {
      'my_profile': 'My Profile',
      'home': 'Home',
      'shop': 'Shop',
      'budget': 'Budget',
      'profile': 'Profile',
      'streak': 'Day Streak',
      'coins': 'Coins',
      'lessons_completed': 'Lessons Completed',
      'settings': 'Settings',
      'language': 'Language',
      'edit_name': 'Edit Name',
      'save': 'Save',
      'select_language': 'Select Language',
      'lessons_title': 'Lessons Completed',
      'budget_management': 'Budget Management',
      'monthly_income': 'Monthly Income (₹)',
      'categories': 'Categories',
      'summary': 'Summary',
      'total_income': 'Total Income',
      'total_allocated': 'Total Allocated',
      'remaining_balance': 'Remaining Balance',
      'budget_exceeds': 'Your budget exceeds your income.',
      'suggested_breakdown': 'Suggested Budget Breakdown',
      'suggested_desc': 'Here is a recommended baseline for your expenses. You can compare this to your actual allocations above.',
      'save_budget': 'Save Budget',
      'reset_budget': 'Reset Budget',
      'start_quiz': 'Start Quiz',
      'quiz_complete': 'Quiz Completed!',
      'questions': 'Questions',
      'correct_answers': 'Correct Answers',
      'wrong_answers': 'Wrong Answers',
      'try_again': 'Try Again',
      'next': 'Next',
      'streak_freeze': 'Streak Freeze',
      'streak_freeze_desc': 'Keep your streak safe for one full day of inactivity.',
      'double_coin': 'Double Coin Wager',
      'double_coin_desc': 'Doubles all coin rewards for 7 days after activation.',
      'quiz_shield': 'Quiz Shield',
      'quiz_shield_desc': 'Forgive one wrong answer in your next quiz.',
      'my_items': 'My Items',
      'activate': 'Activate',
      'active_until': 'Active until',
      'enter_phone': 'Enter your phone number',
      'continue_btn': 'Continue',
      'phone_info': 'Your phone number will only be used\nto save your progress.',
      'phone_error': 'Please enter a valid 10-digit phone number.',
      'coming_soon': 'Coming Soon',
      'spend_coins': 'Spend your coins on power-ups!',
      'lesson_locked': 'Lesson Locked',
      'lesson_locked_desc': 'Complete the previous lessons to unlock this one.',
      'ok': 'OK',
      'congratulations': 'Congratulations!',
      'you_scored': 'You scored',
      'out_of': 'out of',
      'you_earned': 'You earned',
      'coins_reward': 'coins!',
      'back_to_roadmap': 'Back to Roadmap',
      'check_answer': 'Check Answer',
      'finish_quiz': 'Finish Quiz',
      'my_profile_title': 'My Profile',
      'learner_badge': 'Learner',
      'edit_profile': 'Edit Profile',
      'choose_response': 'Choose your response',
      'food': 'Food',
      'rent': 'Rent',
      'education': 'Education',
      'transport': 'Transport',
      'savings': 'Savings',
      'fixed': 'Fixed',
      'save_success': 'Settings saved successfully!',
      'you': 'You',
      'your_name': 'Your Name',
      'your_progress': 'Your Progress',
      'name_hint': 'Enter your name',
      'correct_answer_was': 'Correct answer:',
      'budget_locked': 'Budget Locked',
      'budget_locked_desc': 'Complete the first 2 lessons to unlock the budget planner',
      'needs_and_wants': 'Needs & Wants',
      'identify_needs_wants_desc': 'Identify your needs and wants to plan better',
      'plan_needs_wants': 'Plan Needs & Wants',
      'quiz_load_error': "Couldn't Load Quiz",
      'quiz_load_error_desc': 'Check your connection and try again.',
      'guide_name': 'Guide',
      'guide_intro_1': "Hi! I'm Guide. Tap your first lesson below to get started.",
      'guide_intro_2': "Let's meet Sunita — she'll walk you through your first lesson!",
      'guide_intro_3': 'Finish a lesson\'s quiz to earn coins — then spend them in the Shop on power-ups like streak freeze and quiz shield!',
      'skip': 'Skip',
    },
    'hi': {
      'my_profile': 'मेरी प्रोफ़ाइल',
      'home': 'होम',
      'shop': 'शॉप',
      'budget': 'बजट',
      'profile': 'प्रोफ़ाइल',
      'streak': 'दिनों का सिलसिला',
      'coins': 'सिक्के',
      'lessons_completed': 'पूरे किए गए पाठ',
      'settings': 'सेटिंग्स',
      'language': 'भाषा',
      'edit_name': 'नाम संपादित करें',
      'save': 'सहेजें',
      'select_language': 'भाषा चुनें',
      'lessons_title': 'पूरे किए गए पाठ',
      'budget_management': 'बजट प्रबंधन',
      'monthly_income': 'मासिक आय (₹)',
      'categories': 'श्रेणियाँ',
      'summary': 'सारांश',
      'total_income': 'कुल आय',
      'total_allocated': 'कुल आवंटित',
      'remaining_balance': 'शेष राशि',
      'budget_exceeds': 'आपका बजट आपकी आय से अधिक है।',
      'suggested_breakdown': 'सुझाया गया बजट विवरण',
      'suggested_desc': 'यहाँ आपके खर्चों के लिए एक अनुशंसित आधार रेखा दी गई है। आप इसकी तुलना ऊपर अपने वास्तविक आवंटन से कर सकते हैं।',
      'save_budget': 'बजट सहेजें',
      'reset_budget': 'बजट रीसेट करें',
      'start_quiz': 'प्रश्नोत्तरी शुरू करें',
      'quiz_complete': 'प्रश्नोत्तरी पूर्ण!',
      'questions': 'प्रश्न',
      'correct_answers': 'सही उत्तर',
      'wrong_answers': 'गलत उत्तर',
      'try_again': 'पुनः प्रयास करें',
      'next': 'अगला',
      'streak_freeze': 'सिलसिला रोकें',
      'streak_freeze_desc': 'एक दिन की निष्क्रियता के लिए अपना सिलसिला सुरक्षित रखें।',
      'double_coin': 'दोगुना सिक्का दांव',
      'double_coin_desc': 'सक्रियण के बाद 7 दिनों के लिए सभी सिक्का पुरस्कार दोगुने करें',
      'quiz_shield': 'प्रश्नोत्तरी ढाल',
      'quiz_shield_desc': 'अपनी अगली प्रश्नोत्तरी में एक गलत उत्तर को माफ करें।',
      'my_items': 'मेरी वस्तुएँ',
      'activate': 'सक्रिय करें',
      'active_until': 'इस तिथि तक सक्रिय',
      'enter_phone': 'अपना फ़ोन नंबर दर्ज करें',
      'continue_btn': 'आगे बढ़ें',
      'phone_info': 'आपके फ़ोन नंबर का उपयोग केवल आपकी प्रगति को सहेजने के लिए किया जाएगा।',
      'phone_error': 'कृपया एक मान्य 10-अंकीय फ़ोन नंबर दर्ज करें।',
      'coming_soon': 'जल्द ही आ रहा है',
      'spend_coins': 'पावर-अप पर अपने सिक्के खर्च करें!',
      'lesson_locked': 'पाठ बंद है',
      'lesson_locked_desc': 'इसे अनलॉक करने के लिए पिछले पाठों को पूरा करें।',
      'ok': 'ठीक है',
      'congratulations': 'बधाई हो!',
      'you_scored': 'आपने स्कोर किया',
      'out_of': 'में से',
      'you_earned': 'आपने अर्जित किए',
      'coins_reward': 'सिक्के!',
      'back_to_roadmap': 'रोडमैप पर वापस जाएं',
      'check_answer': 'उत्तर जांचें',
      'finish_quiz': 'प्रश्नोत्तरी समाप्त करें',
      'my_profile_title': 'मेरी प्रोफ़ाइल',
      'learner_badge': 'शिक्षार्थी',
      'edit_profile': 'प्रोफ़ाइल संपादित करें',
      'choose_response': 'अपनी प्रतिक्रिया चुनें',
      'food': 'भोजन',
      'rent': 'किराया',
      'education': 'शिक्षा',
      'transport': 'परिवहन',
      'savings': 'बचत',
      'fixed': 'स्थिर',
      'save_success': 'सेटिंग्स सफलतापूर्वक सहेजी गईं!',
      'you': 'आप',
      'your_name': 'आपका नाम',
      'your_progress': 'आपकी प्रगति',
      'name_hint': 'अपना नाम दर्ज करें',
      'correct_answer_was': 'सही उत्तर:',
      'budget_locked': 'बजट लॉक है',
      'budget_locked_desc': 'बजट प्लानर अनलॉक करने के लिए पहले 2 पाठ पूरे करें',
      'needs_and_wants': 'ज़रूरतें और इच्छाएं',
      'identify_needs_wants_desc': 'बेहतर योजना बनाने के लिए अपनी जरूरतों और इच्छाओं को पहचानें',
      'plan_needs_wants': 'जरूरतें और इच्छाएं योजना बनाएं',
      'quiz_load_error': 'प्रश्नोत्तरी लोड नहीं हो सकी',
      'quiz_load_error_desc': 'अपना कनेक्शन जांचें और पुनः प्रयास करें।',
      'guide_name': 'गाइड',
      'guide_intro_1': 'नमस्ते! मैं गाइड हूँ। शुरू करने के लिए नीचे अपना पहला पाठ टैप करें।',
      'guide_intro_2': 'आइए सुनीता से मिलें — वह आपके पहले पाठ में आपका मार्गदर्शन करेंगी!',
      'guide_intro_3': 'पाठ की क्विज़ पूरी करके सिक्के कमाएँ — फिर उन्हें शॉप में स्ट्रीक फ्रीज और क्विज़ शील्ड जैसे पावर-अप्स पर खर्च करें!',
      'skip': 'छोड़ें',
    },
    'kn': {
      'my_profile': 'ನನ್ನ ಪ್ರೊಫೈಲ್',
      'home': 'ಮುಖಪುಟ',
      'shop': 'ಅಂಗಡಿ',
      'budget': 'ಬಜೆಟ್',
      'profile': 'ಪ್ರೊಫೈಲ್',
      'streak': 'ದಿನದ ಸರಣಿ',
      'coins': 'ನಾಣ್ಯಗಳು',
      'lessons_completed': 'ಪೂರ್ಣಗೊಂಡ ಪಾಠಗಳು',
      'settings': 'ಸೆಟ್ಟಿಂಗ್ಸ್',
      'language': 'ಭಾಷೆ',
      'edit_name': 'ಹೆಸರನ್ನು ಸಂಪಾದಿಸಿ',
      'save': 'ಉಳಿಸಿ',
      'select_language': 'ಭಾಷೆಯನ್ನು ಆರಿಸಿ',
      'lessons_title': 'ಪೂರ್ಣಗೊಂಡ ಪಾಠಗಳು',
      'budget_management': 'ಬಜೆಟ್ ನಿರ್ವಹಣೆ',
      'monthly_income': 'ಮಾಸಿಕ ಆದಾಯ (₹)',
      'categories': 'ವರ್ಗಗಳು',
      'summary': 'ಸಾರಾಂಶ',
      'total_income': 'ಒಟ್ಟು ಆದಾಯ',
      'total_allocated': 'ಒಟ್ಟು ಹಂಚಿಕೆ',
      'remaining_balance': 'ಉಳಿದ ಬ್ಯಾಲೆನ್ಸ್',
      'budget_exceeds': 'ನಿಮ್ಮ ಬಜೆಟ್ ನಿಮ್ಮ ಆದಾಯಕ್ಕಿಂತ ಹೆಚ್ಚಾಗಿದೆ.',
      'suggested_breakdown': 'ಶಿಫಾರಸು ಮಾಡಿದ ಬಜೆಟ್ ಹಂಚಿಕೆ',
      'suggested_desc': 'ನಿಮ್ಮ ಖರ್ಚುಗಳಿಗೆ ಶಿಫಾರಸು ಮಾಡಲಾದ ಬೇಸ್‌ಲೈನ್ ಇಲ್ಲಿದೆ. ಮೇಲಿನ ನಿಮ್ಮ ನೈಜ ಹಂಚಿಕೆಗಳಿಗೆ ಇದನ್ನು ಹೋಲಿಸಬಹುದು.',
      'save_budget': 'ಬಜೆಟ್ ಉಳಿಸಿ',
      'reset_budget': 'ಬಜೆಟ್ ಮರುಹೊಂದಿಸಿ',
      'start_quiz': 'ರಸಪ್ರಶ್ನೆ ಪ್ರಾರಂಭಿಸಿ',
      'quiz_complete': 'ರಸಪ್ರಶ್ನೆ ಪೂರ್ಣಗೊಂಡಿದೆ!',
      'questions': 'ಪ್ರಶ್ನೆಗಳು',
      'correct_answers': 'ಸರಿಯಾದ ಉತ್ತರಗಳು',
      'wrong_answers': 'ತಪ್ಪು ಉತ್ತರಗಳು',
      'try_again': 'ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ',
      'next': 'ಮುಂದೆ',
      'streak_freeze': 'ಸರಣಿ ಫ್ರೀಜ್',
      'streak_freeze_desc': 'ಒಂದು ದಿನದ ನಿಷ್ಕ್ರಿಯತೆಗಾಗಿ ನಿಮ್ಮ ಸರಣಿಯನ್ನು ಸುರಕ್ಷಿತವಾಗಿರಿಸಿ.',
      'double_coin': 'ಡಬಲ್ ಕಾಯಿನ್ ಪಣ',
      'double_coin_desc': 'ಸಕ್ರಿಯಗೊಳಿಸಿದ ನಂತರ 7 ದಿನಗಳವರೆಗೆ ಎಲ್ಲಾ ನಾಣ್ಯ ಪುರಸ್ಕಾರಗಳನ್ನು ದ್ವಿಗುಣಗೊಳಿಸಿ.',
      'quiz_shield': 'ಕ್ವಿಜ್ ಶೀಲ್ಡ್',
      'quiz_shield_desc': 'ನಿಮ್ಮ ಮುಂದಿನ ರಸಪ್ರಶ್ನೆಯಲ್ಲಿ ಒಂದು ತಪ್ಪು ಉತ್ತರವನ್ನು ಕ್ಷಮಿಸಿ.',
      'my_items': 'ನನ್ನ ವಸ್ತುಗಳು',
      'activate': 'ಸಕ್ರಿಯಗೊಳಿಸಿ',
      'active_until': 'ಇಲ್ಲಿಯವರೆಗೆ ಸಕ್ರಿಯ',
      'enter_phone': 'ನಿಮ್ಮ ಫೋನ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ',
      'continue_btn': 'ಮುಂದುವರಿಯಿರಿ',
      'phone_info': 'ನಿಮ್ಮ ಪ್ರಗತಿಯನ್ನು ಉಳಿಸಲು ಮಾತ್ರ ನಿಮ್ಮ ಫೋನ್ ಸಂಖ್ಯೆಯನ್ನು ಬಳಸಲಾಗುತ್ತದೆ.',
      'phone_error': 'ದಯವಿಟ್ಟು ಮಾನ್ಯವಾದ 10-ಅಂಕಿಯ ಫೋನ್ ಸಂಖ್ಯೆಯನ್ನು ನಮೂದಿಸಿ.',
      'coming_soon': 'ಶೀಘ್ರದಲ್ಲೇ ಬರಲಿದೆ',
      'spend_coins': 'ಪವರ್-ಅಪ್‌ಗಳಿಗಾಗಿ ನಿಮ್ಮ ನಾಣ್ಯಗಳನ್ನು ಖರ್ಚು ಮಾಡಿ!',
      'lesson_locked': 'ಪಾಠ ಲಾಕ್ ಆಗಿದೆ',
      'lesson_locked_desc': 'ಇದನ್ನು ಅನ್ಲಾಕ್ ಮಾಡಲು ಹಿಂದಿನ ಪಾಠಗಳನ್ನು ಪೂರ್ಣಗೊಳಿಸಿ.',
      'ok': 'ಸರಿ',
      'congratulations': 'ಅಭಿನಂದನೆಗಳು!',
      'you_scored': 'ನೀವು ಗಳಿಸಿದ್ದು',
      'out_of': 'ರಲ್ಲಿ',
      'you_earned': 'ನೀವು ಗಳಿಸಿದ್ದು',
      'coins_reward': 'ನಾಣ್ಯಗಳು!',
      'back_to_roadmap': 'ರೋಡ್‌ಮ್ಯಾಪ್‌ಗೆ ಹಿಂತಿರುಗಿ',
      'check_answer': 'ಉತ್ತರವನ್ನು ಪರಿಶೀಲಿಸಿ',
      'finish_quiz': 'ರಸಪ್ರಶ್ನೆ ಮುಗಿಸಿ',
      'my_profile_title': 'ನನ್ನ ಪ್ರೊಫೈಲ್',
      'learner_badge': 'ಕಲಿಕಾಗಾರ',
      'edit_profile': 'ಪ್ರೊಫೈಲ್ ಸಂಪಾದಿಸಿ',
      'choose_response': 'ನಿಮ್ಮ ಪ್ರತಿಕ್ರಿಯೆಯನ್ನು ಆರಿಸಿ',
      'food': 'ಆಹಾರ',
      'rent': 'ಬಾಡಿಗೆ',
      'education': 'ಶಿಕ್ಷಣ',
      'transport': 'ಸಾರಿಗೆ',
      'savings': 'ಉಳಿತಾಯ',
      'fixed': 'ಸ್ಥಿರ',
      'save_success': 'ಸಂಯೋಜನೆಗಳನ್ನು ಯಶಸ್ವಿಯಾಗಿ ಉಳಿಸಲಾಗಿದೆ!',
      'you': 'ನೀವು',
      'your_name': 'ನಿಮ್ಮ ಹೆಸರು',
      'your_progress': 'ನಿಮ್ಮ ಪ್ರಗತಿ',
      'name_hint': 'ನಿಮ್ಮ ಹೆಸರನ್ನು ನಮೂದಿಸಿ',
      'correct_answer_was': 'ಸರಿಯಾದ ಉತ್ತರ:',
      'budget_locked': 'ಬಜೆಟ್ ಲಾಕ್ ಆಗಿದೆ',
      'budget_locked_desc': 'ಬಜೆಟ್ ಯೋಜಕವನ್ನು ಅನ್ಲಾಕ್ ಮಾಡಲು ಮೊದಲ 2 ಪಾಠಗಳನ್ನು ಪೂರ್ಣಗೊಳಿಸಿ',
      'needs_and_wants': 'ಅಗತ್ಯಗಳು ಮತ್ತು ಬಯಕೆಗಳು',
      'identify_needs_wants_desc': 'ಉತ್ತಮ ಯೋಜನೆ ಮಾಡಲು ನಿಮ್ಮ ಅಗತ್ಯಗಳು ಮತ್ತು ಬಯಕೆಗಳನ್ನು ಗುರುತಿಸಿ',
      'plan_needs_wants': 'ಅಗತ್ಯಗಳು ಮತ್ತು ಬಯಕೆಗಳನ್ನು ಯೋಜಿಸಿ',
      'quiz_load_error': 'ರಸಪ್ರಶ್ನೆ ಲೋಡ್ ಆಗಲಿಲ್ಲ',
      'quiz_load_error_desc': 'ನಿಮ್ಮ ಸಂಪರ್ಕವನ್ನು ಪರಿಶೀಲಿಸಿ ಮತ್ತು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',
      'guide_name': 'ಗೈಡ್',
      'guide_intro_1': 'ನಮಸ್ಕಾರ! ನಾನು ಗೈಡ್. ಪ್ರಾರಂಭಿಸಲು ಕೆಳಗಿನ ನಿಮ್ಮ ಮೊದಲ ಪಾಠವನ್ನು ಟ್ಯಾಪ್ ಮಾಡಿ.',
      'guide_intro_2': 'ಸುನಿತಾರನ್ನು ಭೇಟಿ ಮಾಡೋಣ — ಅವರು ನಿಮ್ಮ ಮೊದಲ ಪಾಠದಲ್ಲಿ ನಿಮಗೆ ಮಾರ್ಗದರ್ಶನ ನೀಡುತ್ತಾರೆ!',
      'guide_intro_3': 'ಪಾಠದ ರಸಪ್ರಶ್ನೆ ಮುಗಿಸಿ ನಾಣ್ಯಗಳನ್ನು ಗಳಿಸಿ — ನಂತರ ಅವುಗಳನ್ನು ಅಂಗಡಿಯಲ್ಲಿ ಸ್ಟ್ರೀಕ್ ಫ್ರೀಜ್ ಮತ್ತು ಕ್ವಿಜ್ ಶೀಲ್ಡ್‌ನಂತಹ ಪವರ್-ಅಪ್‌ಗಳ ಮೇಲೆ ಖರ್ಚು ಮಾಡಿ!',
      'skip': 'ಬಿಟ್ಟುಬಿಡಿ',
    }
  };

  static final translator = GoogleTranslator();

  // Synchronous static lookup for common labels
  static String translate(BuildContext context, String key) {
    final provider = LanguageProvider.of(context);
    final lang = provider?.languageCode ?? 'en';
    return staticTranslations[lang]?[key] ?? staticTranslations['en']?[key] ?? key;
  }

  // Asynchronous live translation for dynamic texts (lessons, dialogs)
  static Future<String> translateDynamic(BuildContext context, String text) async {
    if (text.isEmpty) return text;
    
    final provider = LanguageProvider.of(context);
    final targetLang = provider?.languageCode ?? 'en';
    
    if (targetLang == 'en') return text;
    
    try {
      final translation = await translator.translate(text, to: targetLang);
      return translation.text;
    } catch (e) {
      return text; // Return original text if offline or translation fails
    }
  }
}

class TranslatedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const TranslatedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: TranslationService.translateDynamic(context, text),
      builder: (context, snapshot) {
        return Text(
          snapshot.data ?? text,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }
}
