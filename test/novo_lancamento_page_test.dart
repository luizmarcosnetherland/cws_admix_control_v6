import 'package:cws_admix_control/data/models/concretagem_model.dart';
import 'package:cws_admix_control/features/obras/pages/novo_lancamento_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renderiza campos principais do novo lancamento', (tester) async {
    final now = DateTime(2026, 4, 24, 9);

    await tester.pumpWidget(
      MaterialApp(
        home: NovoLancamentoPage(
          obraNome: 'Obra Teste',
          concretagem: Concretagem(
            id: 1,
            obraId: 1,
            estruturaConcretada: 'Laje',
            concreteira: 'Concreteira Teste',
            createdAt: now,
            updatedAt: now,
          ),
        ),
      ),
    );

    expect(find.text('Novo Lançamento'), findsOneWidget);
    expect(find.text('Betoneira * (nº/placa)'), findsOneWidget);
    expect(find.text('Nota fiscal (NF)'), findsOneWidget);
    expect(find.text('Volume (m³) *'), findsOneWidget);
    expect(find.text('Dosagem (kg/m³) *'), findsOneWidget);
  });
}
