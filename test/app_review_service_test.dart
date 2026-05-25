import 'package:cws_admix_control/core/services/app_review_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('nao sugere avaliacao fora de Android e iOS', () async {
    final service = AppReviewService(targetPlatform: TargetPlatform.macOS);

    expect(await service.recordCompletedTaskAndShouldPrompt(), isFalse);
  });

  test('sugere avaliacao apos duas tarefas e respeita intervalo', () async {
    final service = AppReviewService(targetPlatform: TargetPlatform.android);

    expect(await service.recordCompletedTaskAndShouldPrompt(), isFalse);
    expect(await service.recordCompletedTaskAndShouldPrompt(), isTrue);
    expect(await service.recordCompletedTaskAndShouldPrompt(), isFalse);
  });

  test('usa Apple ID padrao do App Store Connect', () {
    expect(AppReviewService.appStoreId, '6760675593');
  });
}
