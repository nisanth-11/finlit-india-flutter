import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/lesson.dart';

class ApiService {
  static final String baseUrl = kIsWeb
      ? 'http://127.0.0.1:8000'
      : (defaultTargetPlatform == TargetPlatform.android
          // ? 'http://10.0.2.2:8000'
          ? 'http://192.168.0.100:8000'
          : 'http://127.0.0.1:8000');

  static Future<List<Lesson>> fetchLessons() async {
    final response = await http.get(Uri.parse('$baseUrl/lessons'));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => Lesson.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load lessons');
    }
  }

  static Future<List<QuizQuestion>> fetchQuiz(String lessonId) async {
    final response = await http.get(Uri.parse('$baseUrl/quiz/$lessonId'));
    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => QuizQuestion.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load quiz');
    }
  }

  static Future<void> updateProfile(String userId, String name, String language) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/auth/profile'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId, 'name': name, 'language': language}),
      );
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> registerUser(String phone) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'phone': phone}),
    );
    return json.decode(response.body);
  }

  // Recovers an existing user's user_id by phone number. Used when
  // registerUser fails because the phone is already registered, so the app
  // can resume the existing account instead of getting stuck with no
  // user_id (which silently disables lesson locking and coin rewards).
  static Future<Map<String, dynamic>> loginUser(String phone) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'phone': phone}),
    );
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> saveProgress(String userId, String lessonId, bool isCompleted) async {
    final response = await http.post(
      Uri.parse('$baseUrl/progress'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'lesson_id': lessonId,
        'is_completed': isCompleted,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return {'bonus_coins_earned': 0};
  }

  static Future<List<dynamic>> fetchProgress(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/progress/$userId'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['progress'];
    }
    return [];
  }

  static Future<Map<String, dynamic>> getUserStats(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/user/$userId'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return {'streak_count': 0, 'coins': 0};
  }

  static Future<Map<String, dynamic>> submitQuizResult(String userId, String lessonId, List<int?> answers, {bool isReplay = false}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/quiz/result'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId,
        'lesson_id': lessonId,
        'answers': answers.map((a) => a ?? -1).toList(),
        'is_replay': isReplay,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return {'coins_earned': 0};
  }

  // Returns the user's quiz results as a list of {lesson_id, score} maps.
  // Score is a percentage (100 == perfect / "golden").
  static Future<List<dynamic>> fetchQuizResults(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/quiz/results/$userId'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['results'] ?? [];
    }
    return [];
  }

  // SHOP
  // Buys a shop item. Returns the decoded response on success. On failure
  // (e.g. not enough coins) returns a map with an 'error' key so callers can
  // distinguish the "Not enough coins" case.
  static Future<Map<String, dynamic>> buyItem(String userId, String item) async {
    final response = await http.post(
      Uri.parse('$baseUrl/shop/buy'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user_id': userId, 'item': item}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    String detail = 'Purchase failed';
    try {
      detail = json.decode(response.body)['detail'] ?? detail;
    } catch (_) {}
    return {'error': detail};
  }

  static Future<Map<String, dynamic>> getShopItems(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/shop/items/$userId'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return {
      'streak_freeze_count': 0,
      'double_coin_count': 0,
      'quiz_shield_count': 0,
      'double_coin_active_until': null,
    };
  }

  static Future<Map<String, dynamic>> activateDoubleCoin(String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/shop/activate/double_coin'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user_id': userId}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return {'error': 'Activation failed'};
  }

  static Future<Map<String, dynamic>> useItem(String userId, String item) async {
    final response = await http.post(
      Uri.parse('$baseUrl/shop/use/$item'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user_id': userId}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return {'error': 'Use failed'};
  }

  static Future<Map<String, dynamic>?> getBudget(String userId) async {
    final response = await http.get(Uri.parse('$baseUrl/budget/$userId'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return null;
  }

  static Future<void> saveBudget(Map<String, dynamic> budgetData) async {
    await http.post(
      Uri.parse('$baseUrl/budget'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(budgetData),
    );
  }
}
