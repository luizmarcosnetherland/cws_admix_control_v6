import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateInfo {
  final String appName;
  final String installedVersion;
  final String installedBuildNumber;
  final String storeVersion;
  final Uri storeUri;

  const AppUpdateInfo({
    required this.appName,
    required this.installedVersion,
    required this.installedBuildNumber,
    required this.storeVersion,
    required this.storeUri,
  });
}

class AppUpdateService {
  final String countryCode;
  final TargetPlatform? _targetPlatformOverride;
  final http.Client _client;
  final bool _ownsClient;

  AppUpdateService({
    http.Client? client,
    TargetPlatform? targetPlatform,
    this.countryCode = 'br',
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _targetPlatformOverride = targetPlatform;

  TargetPlatform get _targetPlatform =>
      _targetPlatformOverride ?? defaultTargetPlatform;

  Future<AppUpdateInfo?> checkForUpdate({PackageInfo? packageInfo}) async {
    if (kIsWeb || _targetPlatform != TargetPlatform.iOS) return null;

    final info = packageInfo ?? await PackageInfo.fromPlatform();
    final bundleId = info.packageName.trim();
    if (bundleId.isEmpty) return null;

    final storeInfo = await _lookupAppStore(bundleId);
    if (storeInfo == null) return null;
    if (!isStoreVersionNewer(info.version, storeInfo.version)) return null;

    return AppUpdateInfo(
      appName: storeInfo.appName,
      installedVersion: info.version,
      installedBuildNumber: info.buildNumber,
      storeVersion: storeInfo.version,
      storeUri: storeInfo.storeUri,
    );
  }

  Future<_AppStoreLookupResult?> _lookupAppStore(String bundleId) async {
    final uri = Uri.https('itunes.apple.com', '/lookup', {
      'bundleId': bundleId,
      'country': countryCode,
    });

    final response = await _client.get(uri).timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    final results = decoded['results'];
    if (results is! List || results.isEmpty) return null;

    final firstResult = results.first;
    if (firstResult is! Map<String, dynamic>) return null;

    final version = (firstResult['version'] as String?)?.trim();
    final storeUrl = (firstResult['trackViewUrl'] as String?)?.trim();
    final appName = (firstResult['trackName'] as String?)?.trim();
    final storeUri = storeUrl == null ? null : Uri.tryParse(storeUrl);

    if (version == null ||
        version.isEmpty ||
        appName == null ||
        appName.isEmpty ||
        storeUri == null) {
      return null;
    }

    return _AppStoreLookupResult(
      appName: appName,
      version: version,
      storeUri: storeUri,
    );
  }

  @visibleForTesting
  static bool isStoreVersionNewer(
    String installedVersion,
    String storeVersion,
  ) {
    return _compareVersions(storeVersion, installedVersion) > 0;
  }

  static int _compareVersions(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);
    final length = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;

    for (var i = 0; i < length; i++) {
      final leftPart = i < leftParts.length ? leftParts[i] : 0;
      final rightPart = i < rightParts.length ? rightParts[i] : 0;
      if (leftPart != rightPart) return leftPart.compareTo(rightPart);
    }

    return 0;
  }

  static List<int> _versionParts(String version) {
    return version
        .split(RegExp(r'[^0-9]+'))
        .where((part) => part.isNotEmpty)
        .map(int.parse)
        .toList(growable: false);
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}

class _AppStoreLookupResult {
  final String appName;
  final String version;
  final Uri storeUri;

  const _AppStoreLookupResult({
    required this.appName,
    required this.version,
    required this.storeUri,
  });
}
