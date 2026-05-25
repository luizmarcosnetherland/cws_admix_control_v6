import 'package:cws_admix_control/core/services/onboarding_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('mostra onboarding ate marcar como visto', () async {
    final service = OnboardingService();

    expect(await service.shouldShowHomeOnboarding(), isTrue);

    await service.markHomeOnboardingSeen();
    expect(await service.shouldShowHomeOnboarding(), isFalse);
  });

  test('reset permite rever onboarding', () async {
    final service = OnboardingService();

    await service.markHomeOnboardingSeen();
    await service.resetHomeOnboarding();

    expect(await service.shouldShowHomeOnboarding(), isTrue);
  });
}
