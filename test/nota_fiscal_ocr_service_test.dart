import 'package:cws_admix_control/core/services/nota_fiscal_ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extrai dados principais e marca intervalo acima de 2h30', () {
    final result = NotaFiscalOcrService.parseText('''
      DANFE - Nota Fiscal Eletronica
      NF-e Nº 000123
      Volume de concreto: 8,0 m3
      Lacre: LC-98765
      Traço: C30 S100 Brita 1
      Horario de carregamento: 08:10
      ''', dataHoraDescarga: DateTime(2026, 4, 30, 11));

    expect(result.numeroNotaFiscal, '000123');
    expect(result.volumeM3, 8);
    expect(result.lacre, 'LC-98765');
    expect(result.traco, 'C30 S100 Brita 1');
    expect(result.horarioCarregamento, DateTime(2026, 4, 30, 8, 10));
    expect(
      result.intervaloCargaDescarga,
      const Duration(hours: 2, minutes: 50),
    );
    expect(result.cargaDescargaAcimaDoLimite, isTrue);
  });

  test('mantem intervalo dentro do limite sem alerta', () {
    final result = NotaFiscalOcrService.parseText('''
      NF 4567
      Volume 6,5 m³
      Lacre numero A123
      FCK 35 MPa
      Carga 09h20
      ''', dataHoraDescarga: DateTime(2026, 4, 30, 11, 30));

    expect(result.numeroNotaFiscal, '4567');
    expect(result.volumeM3, 6.5);
    expect(result.lacre, 'A123');
    expect(result.traco, '35 MPa');
    expect(
      result.intervaloCargaDescarga,
      const Duration(hours: 2, minutes: 10),
    );
    expect(result.cargaDescargaAcimaDoLimite, isFalse);
  });
}
