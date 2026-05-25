import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum AppReviewRequestResult {
  requested,
  openedStore,
  missingAppStoreId,
  unsupportedPlatform,
  failed,
}

class AppReviewService {
  static const String appStoreId = String.fromEnvironment(
    'APP_STORE_ID',
    defaultValue: '6760675593',
  );
  static const String playStorePackageName = String.fromEnvironment(
    'PLAY_STORE_PACKAGE_NAME',
    defaultValue: 'br.com.netherland.cwsadmixcontrol',
  );

  static const String _completedTasksKey = 'review_completed_tasks_v1';
  static const String _lastPromptAtKey = 'review_last_prompt_at_v1';
  static const String _reviewRequestedKey = 'review_requested_v1';
  static const int _minimumCompletedTasksBeforePrompt = 2;
  static const Duration _minimumPromptInterval = Duration(days: 21);
  static const String _supportEmail = 'netherland@netherland.com.br';

  final TargetPlatform? _targetPlatformOverride;
  final InAppReview _inAppReview;

  AppReviewService({TargetPlatform? targetPlatform, InAppReview? inAppReview})
    : _targetPlatformOverride = targetPlatform,
      _inAppReview = inAppReview ?? InAppReview.instance;

  TargetPlatform get _targetPlatform =>
      _targetPlatformOverride ?? defaultTargetPlatform;

  bool get _isReviewPlatform {
    if (kIsWeb) return false;
    return _targetPlatform == TargetPlatform.android ||
        _targetPlatform == TargetPlatform.iOS;
  }

  Future<bool> recordCompletedTaskAndShouldPrompt() async {
    if (!_isReviewPlatform) return false;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_reviewRequestedKey) ?? false) return false;

    final completedTasks = (prefs.getInt(_completedTasksKey) ?? 0) + 1;
    await prefs.setInt(_completedTasksKey, completedTasks);

    if (completedTasks < _minimumCompletedTasksBeforePrompt) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final lastPromptAt = prefs.getInt(_lastPromptAtKey);
    if (lastPromptAt != null &&
        now - lastPromptAt < _minimumPromptInterval.inMilliseconds) {
      return false;
    }

    await prefs.setInt(_lastPromptAtKey, now);
    return true;
  }

  Future<void> markReviewRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reviewRequestedKey, true);
  }

  Future<AppReviewRequestResult> requestReview() async {
    if (!_isReviewPlatform) return AppReviewRequestResult.unsupportedPlatform;

    try {
      final available = await _inAppReview.isAvailable();
      if (available) {
        await _inAppReview.requestReview();
        await markReviewRequested();
        return AppReviewRequestResult.requested;
      }
    } catch (_) {
      return openStoreListing();
    }

    return openStoreListing();
  }

  Future<AppReviewRequestResult> openStoreListing() async {
    if (!_isReviewPlatform) return AppReviewRequestResult.unsupportedPlatform;

    if (_targetPlatform == TargetPlatform.iOS && appStoreId.trim().isEmpty) {
      return AppReviewRequestResult.missingAppStoreId;
    }

    try {
      await _inAppReview.openStoreListing(
        appStoreId: appStoreId.trim().isEmpty ? null : appStoreId.trim(),
      );
      await markReviewRequested();
      return AppReviewRequestResult.openedStore;
    } catch (_) {
      final fallbackOpened = await _openStoreFallback();
      if (fallbackOpened) {
        await markReviewRequested();
        return AppReviewRequestResult.openedStore;
      }
      return AppReviewRequestResult.failed;
    }
  }

  Future<bool> openFeedbackEmail({String? versionLabel}) {
    final body = [
      if (versionLabel != null && versionLabel.trim().isNotEmpty)
        'Versao: ${versionLabel.trim()}',
      'Plataforma: ${_platformLabel()}',
      '',
      'Conte aqui sua sugestao, problema ou melhoria:',
      '',
    ].join('\n');

    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': 'Feedback - CWS Admix Control',
        'body': body,
      },
    );

    return launchUrl(uri);
  }

  Future<bool> _openStoreFallback() {
    final uri = switch (_targetPlatform) {
      TargetPlatform.android => Uri.parse(
        'https://play.google.com/store/apps/details?id=$playStorePackageName',
      ),
      TargetPlatform.iOS => Uri.parse(
        'https://apps.apple.com/app/id${appStoreId.trim()}?action=write-review',
      ),
      _ => null,
    };

    if (uri == null) return Future<bool>.value(false);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _platformLabel() {
    if (kIsWeb) return 'Web';
    return switch (_targetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
  }
}
