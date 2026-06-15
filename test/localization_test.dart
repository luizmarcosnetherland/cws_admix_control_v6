import 'package:cws_admix_control/core/branding/brand_assets.dart';
import 'package:cws_admix_control/core/localization/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    CwsLocalizations.activate(CwsLocalizations(const Locale('pt', 'BR')));
  });

  test('resolve idiomas suportados e usa portugues como fallback', () {
    expect(
      CwsLocalizations.resolve(
        const Locale('en', 'US'),
        CwsLocalizations.supportedLocales,
      ),
      const Locale('en'),
    );
    expect(
      CwsLocalizations.resolve(
        const Locale('es', 'CL'),
        CwsLocalizations.supportedLocales,
      ),
      const Locale('es'),
    );
    expect(
      CwsLocalizations.resolve(
        const Locale('fr', 'FR'),
        CwsLocalizations.supportedLocales,
      ),
      const Locale('pt', 'BR'),
    );
  });

  test('usa marca Netherland apenas para portugues do Brasil', () {
    expect(isPtBrLocale(const Locale('pt', 'BR')), isTrue);
    expect(isPtBrLocale(const Locale('pt', 'PT')), isFalse);
    expect(isPtBrLocale(const Locale('en', 'US')), isFalse);

    expect(
      companyLogoAssetForLocale(const Locale('pt', 'BR')),
      kNetherlandLogoAsset,
    );
    expect(
      companyLogoAssetForLocale(const Locale('en', 'US')),
      kCwsWaterproofingLogoAsset,
    );
    expect(
      companyLogoAssetForLocale(const Locale('fr', 'FR')),
      kCwsWaterproofingLogoAsset,
    );
  });

  test('traduz textos principais para ingles e espanhol', () {
    CwsLocalizations.activate(CwsLocalizations(const Locale('en')));
    expect(tr('Calculadora CWS'), 'CWS Calculator');
    expect(tr('Agendamento de Concretagem'), 'Concrete Pour Scheduling');
    expect(tr('Nova Obra'), 'New Jobsite');
    expect(tr('Rastreio da Planta'), 'Plan Tracking');
    expect(tr('Lançamentos: {count}', params: {'count': 3}), 'Placements: 3');
    expect(tr('Nome'), 'Name');
    expect(tr('Responsavel'), 'Person in charge');
    expect(tr('E-mail engenheiro'), 'Responsible email');
    expect(tr('Empresa tecnologia'), 'Quality control company');
    expect(tr('Primeiro lancamento'), '1st pour');
    expect(tr('Lançamentos da concretagem'), 'Pour batches');

    CwsLocalizations.activate(CwsLocalizations(const Locale('es')));
    expect(tr('Calculadora CWS'), 'Calculadora CWS');
    expect(tr('Agendamento de Concretagem'), 'Programación de Hormigonado');
    expect(tr('Nova Obra'), 'Nueva Obra');
    expect(tr('Rastreio da Planta'), 'Rastreo de la Planta');
    expect(tr('Lançamentos: {count}', params: {'count': 3}), 'Lanzamientos: 3');
  });

  test('usa textos amigaveis em portugues e limpa erros tecnicos', () {
    CwsLocalizations.activate(CwsLocalizations(const Locale('pt', 'BR')));

    expect(
      tr('CWS Admix previsto: informe o volume.'),
      'Informe o volume para ver o CWS Admix previsto.',
    );
    expect(
      tr(
        'Erro ao preparar agendamento: {error}',
        params: {
          'error': PlatformException(
            code: 'calendar_unavailable',
            message:
                'Não encontramos um aplicativo de calendário para criar o evento.',
          ),
        },
      ),
      'Não foi possível preparar o agendamento. Detalhes: '
      'Não encontramos um aplicativo de calendário para criar o evento.',
    );
    expect(
      tr(
        'Erro ao abrir mapa: {error}',
        params: {'error': Exception('Nao foi possivel abrir o app de mapas.')},
      ),
      'Não foi possível abrir o mapa. Detalhes: '
      'Não conseguimos abrir o app de mapas.',
    );
  });
}
