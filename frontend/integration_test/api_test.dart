import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/api_service.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('test api registration, lessons, and budget flow', (tester) async {
    final phone = '9${DateTime.now().millisecondsSinceEpoch.toString().substring(4, 13)}';

    // Register a new user
    final registerResponse = await ApiService.registerUser(phone);
    expect(registerResponse.containsKey('user_id'), true);
    final userId = registerResponse['user_id'] as String;

    // Fetch lessons list
    final lessons = await ApiService.fetchLessons();
    expect(lessons.isNotEmpty, true);

    // Save budget data
    final budgetData = {
      'user_id': userId,
      'totalIncome': 10000.0,
      'food': 3000.0,
      'rent': 2000.0,
      'education': 1500.0,
      'transport': 500.0,
      'savings': 3000.0,
    };
    await ApiService.saveBudget(budgetData);

    // Retrieve and verify budget
    final budget = await ApiService.getBudget(userId);
    expect(budget, isNotNull);
    expect(budget!['totalIncome'], 10000.0);
    expect(budget['food'], 3000.0);
    expect(budget['rent'], 2000.0);
  });
}
