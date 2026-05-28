import 'package:cws_admix_control/core/localization/app_localizations.dart';
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

  test('traduz textos principais para ingles e espanhol', () {
    CwsLocalizations.activate(CwsLocalizations(const Locale('en')));
    expect(tr('Calculadora CWS'), 'CWS Calculator');
    expect(tr('Agendamento de Concretagem'), 'Concrete Pour Scheduling');
    expect(tr('Nova Obra'), 'New Jobsite');
    expect(tr('Rastreio da Planta'), 'Plan Tracking');
    expect(tr('Lançamentos: {count}', params: {'count': 3}), 'Placements: 3');

    CwsLocalizations.activate(CwsLocalizations(const Locale('es')));
    expect(tr('Calculadora CWS'), 'Calculadora CWS');
    expect(tr('Agendamento de Concretagem'), 'Programación de Hormigonado');
    expect(tr('Nova Obra'), 'Nueva Obra');
    expect(tr('Rastreio da Planta'), 'Rastreo de la Planta');
    expect(tr('Lançamentos: {count}', params: {'count': 3}), 'Lanzamientos: 3');
  });
}
