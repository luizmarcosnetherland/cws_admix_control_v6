import 'package:cws_admix_control/core/localization/app_localizations.dart';
import 'package:cws_admix_control/cws_calculator_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    CwsLocalizations.activate(CwsLocalizations(const Locale('pt', 'BR')));
  });

  testWidgets('calcula por volume com dosagem padrão de 0,80 kg/m³', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CwsCalculatorPage(initialVolumeM3: 10)),
    );

    expect(find.text('Consumo de cimento (kg/m³)'), findsNothing);
    expect(find.text('0,80 kg/m³'), findsOneWidget);
    expect(find.text('8,0 kg'), findsOneWidget);
    expect(find.text('Recalcular com dosagem de 1,0 kg/m³'), findsOneWidget);
  });

  testWidgets('recalcula para 1,0 kg/m³ quando o consumo supera 450 kg/m³', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CwsCalculatorPage(initialVolumeM3: 10)),
    );

    await tester.tap(find.text('Recalcular com dosagem de 1,0 kg/m³'));
    await tester.pump();

    expect(find.text('1,00 kg/m³'), findsOneWidget);
    expect(find.text('10,0 kg'), findsOneWidget);
    expect(
      find.text('Cálculo ajustado para consumo de cimento acima de 450 kg/m³.'),
      findsOneWidget,
    );
    expect(find.text('Usar dosagem padrão de 0,80 kg/m³'), findsOneWidget);
  });
}
