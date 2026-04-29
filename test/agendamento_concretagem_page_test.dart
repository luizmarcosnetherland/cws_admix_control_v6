import 'package:cws_admix_control/cws_calculator_page.dart';
import 'package:cws_admix_control/features/agendamento/pages/agendamento_concretagem_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renderiza campos e acoes do agendamento de concretagem', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AgendamentoConcretagemPage()),
    );

    expect(find.text('Agendamento de Concretagem'), findsOneWidget);
    expect(find.text('Data da concretagem *'), findsOneWidget);
    expect(find.text('Horário previsto de início *'), findsOneWidget);
    expect(find.text('Volume estimado (m³)'), findsOneWidget);
    expect(find.text('Estrutura a ser concretada'), findsOneWidget);
    expect(find.text('Traço do concreto'), findsOneWidget);
    expect(find.text('CWS Admix previsto: informe o volume.'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Volume estimado (m³)'),
      '10',
    );
    await tester.pump();
    expect(find.text('CWS Admix previsto: 8,00 kg'), findsOneWidget);

    expect(find.text('E-mail para convite'), findsNothing);

    expect(find.text('AGENDAR'), findsOneWidget);
    expect(find.text('Compartilhar WhatsApp'), findsOneWidget);
    expect(find.text('Fazer pedido de CWS Admix'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('calculadora recebe volume inicial do agendamento', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CwsCalculatorPage(initialVolumeM3: 10)),
    );

    expect(find.text('Calculadora CWS'), findsOneWidget);
    final volumeField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Volume de concreto (m³)'),
    );
    expect(volumeField.controller?.text, '10');
  });
}
