import 'dart:convert';

import 'package:cws_admix_control/core/services/app_update_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  PackageInfo packageInfo({
    String version = '1.0.7',
    String buildNumber = '23',
  }) {
    return PackageInfo(
      appName: 'CWS Admix Control',
      packageName: 'br.com.netherland.cwsadmixcontrol',
      version: version,
      buildNumber: buildNumber,
    );
  }

  http.Response appStoreResponse({required String version}) {
    return http.Response(
      jsonEncode({
        'resultCount': 1,
        'results': [
          {
            'trackName': 'CWS Admix Control',
            'version': version,
            'trackViewUrl':
                'https://apps.apple.com/br/app/cws-admix-control/id123456789',
          },
        ],
      }),
      200,
    );
  }

  test('compara versoes sem tratar 1.0.10 como menor que 1.0.7', () {
    expect(AppUpdateService.isStoreVersionNewer('1.0.7', '1.0.10'), isTrue);
    expect(AppUpdateService.isStoreVersionNewer('1.0.10', '1.0.7'), isFalse);
    expect(AppUpdateService.isStoreVersionNewer('1.0.7', '1.0.7'), isFalse);
  });

  test('retorna atualizacao quando a App Store tem versao mais nova', () async {
    final service = AppUpdateService(
      targetPlatform: TargetPlatform.iOS,
      client: MockClient((request) async {
        expect(request.url.host, 'itunes.apple.com');
        expect(
          request.url.queryParameters['bundleId'],
          'br.com.netherland.cwsadmixcontrol',
        );
        return appStoreResponse(version: '1.0.8');
      }),
    );
    addTearDown(service.dispose);

    final update = await service.checkForUpdate(packageInfo: packageInfo());

    expect(update, isNotNull);
    expect(update!.storeVersion, '1.0.8');
    expect(update.installedVersion, '1.0.7');
    expect(update.installedBuildNumber, '23');
  });

  test(
    'nao retorna atualizacao quando a versao instalada ja e atual',
    () async {
      final service = AppUpdateService(
        targetPlatform: TargetPlatform.iOS,
        client: MockClient((_) async => appStoreResponse(version: '1.0.7')),
      );
      addTearDown(service.dispose);

      final update = await service.checkForUpdate(packageInfo: packageInfo());

      expect(update, isNull);
    },
  );

  test('nao consulta App Store fora do iOS', () async {
    final service = AppUpdateService(
      targetPlatform: TargetPlatform.android,
      client: MockClient(
        (_) async => throw StateError('Nao deveria consultar'),
      ),
    );
    addTearDown(service.dispose);

    final update = await service.checkForUpdate(packageInfo: packageInfo());

    expect(update, isNull);
  });
}
