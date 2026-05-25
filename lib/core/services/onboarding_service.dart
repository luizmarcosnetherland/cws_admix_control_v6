import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _seenKey = 'home_onboarding_seen_v1';

  Future<bool> shouldShowHomeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_seenKey) ?? false);
  }

  Future<void> markHomeOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }

  Future<void> resetHomeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_seenKey);
  }
}
