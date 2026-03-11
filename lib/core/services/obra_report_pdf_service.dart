import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../data/models/lancamento_model.dart';
import '../../data/models/obra_model.dart';
import 'local_dropbox_storage_service.dart';

class ObraReportPdfService {
  final LocalDropboxStorageService _storage = LocalDropboxStorageService();
  static const _lancamentoCardWidth = 168.0;

  Future<String> buildReportPdf({
    required Obra obra,
    required List<Lancamento> lancamentos,
    required String periodoLabel,
    required String ordenacaoLabel,
    String? concreteira,
    String? betoneira,
    String? busca,
  }) async {
    final doc = pw.Document();
    final logos = await _loadLogos();
    final fonts = await _loadFonts();
    final lancamentoCards = await _buildLancamentoCards(lancamentos);
    final generatedAt = DateTime.now();
    final generatedAtLabel = DateFormat(
      'dd/MM/yyyy HH:mm',
      'pt_BR',
    ).format(generatedAt);

    double volumeTotal = 0;
    double cwsTotal = 0;
    for (final lancamento in lancamentos) {
      volumeTotal += lancamento.volumeM3;
      cwsTotal += lancamento.cwsTotalKg;
    }
    final ultimoLancamento = lancamentos.isEmpty
        ? null
        : lancamentos
              .map((l) => l.dataHora)
              .reduce((a, b) => a.isAfter(b) ? a : b);
    final curaUmidaAte = ultimoLancamento?.add(const Duration(days: 7));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Relatório gerado em $generatedAtLabel',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
        ),
        build: (_) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (logos.netherland != null)
                pw.Image(logos.netherland!, height: 34),
              if (logos.cws != null) pw.Image(logos.cws!, height: 34),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Relatório da obra ${obra.nome}',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Gerado em $generatedAtLabel',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Divider(),
          _sectionTitle('Obra'),
          _kv('Cliente', _fallback(obra.cliente)),
          _kv('Local', _fallback(obra.local)),
          _kv('Responsável', _fallback(obra.responsavel)),
          _kv('E-mail engenheiro', _fallback(obra.emailEngenheiro)),
          pw.SizedBox(height: 10),
          _sectionTitle('Filtros aplicados'),
          _kv('Período', _pdfSafe(periodoLabel)),
          _kv('Ordenação', _pdfSafe(ordenacaoLabel)),
          if (concreteira != null) _kv('Concreteira', _pdfSafe(concreteira)),
          if (betoneira != null) _kv('Betoneira', _pdfSafe(betoneira)),
          if (busca != null && busca.trim().isNotEmpty)
            _kv('Busca', _pdfSafe(busca.trim())),
          pw.SizedBox(height: 10),
          _sectionTitle('Resumo'),
          _kv('Lançamentos', '${lancamentos.length}'),
          _kv('Volume total', '${_fmtNum(volumeTotal, 3)} m³'),
          _kv('CWS total', '${_fmtNum(cwsTotal, 3)} kg'),
          _kv(
            'Cura úmida recomendada até',
            curaUmidaAte == null
                ? '-'
                : DateFormat('dd/MM/yyyy', 'pt_BR').format(curaUmidaAte),
          ),
          pw.SizedBox(height: 12),
          _sectionTitle('Lançamentos'),
          pw.Wrap(spacing: 8, runSpacing: 8, children: lancamentoCards),
        ],
      ),
    );

    await _storage.ensureBaseStructure();
    final filePath = await _storage.exportFilePath(
      'Relatorio_Obra_${_safeFile(obra.nome)}_${_timestamp()}.pdf',
    );
    final file = File(filePath);
    await file.writeAsBytes(await doc.save(), flush: true);
    return file.path;
  }

  Future<void> shareReportPdf({
    required Obra obra,
    required List<Lancamento> lancamentos,
    required String periodoLabel,
    required String ordenacaoLabel,
    String? concreteira,
    String? betoneira,
    String? busca,
    Rect? sharePositionOrigin,
  }) async {
    final path = await buildReportPdf(
      obra: obra,
      lancamentos: lancamentos,
      periodoLabel: periodoLabel,
      ordenacaoLabel: ordenacaoLabel,
      concreteira: concreteira,
      betoneira: betoneira,
      busca: busca,
    );

    await Share.shareXFiles(
      [XFile(path)],
      text: 'Relatório em PDF da obra ${obra.nome}',
      subject: 'Relatório da obra ${obra.nome}',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _kv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              _pdfSafe(label),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              _pdfSafe(value),
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<pw.Widget>> _buildLancamentoCards(
    List<Lancamento> lancamentos,
  ) async {
    final cards = <pw.Widget>[];
    for (final lancamento in lancamentos) {
      final fotos = await _loadLancamentoPhotos(lancamento);
      cards.add(
        pw.SizedBox(
          width: _lancamentoCardWidth,
          child: _lancamentoCardWithPhotos(lancamento, fotos),
        ),
      );
    }
    return cards;
  }

  Future<List<pw.MemoryImage>> _loadLancamentoPhotos(
    Lancamento lancamento,
  ) async {
    final fotos = <pw.MemoryImage>[];
    for (final path in lancamento.fotoPaths) {
      try {
        final file = File(path);
        if (!await file.exists()) continue;
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;
        fotos.add(pw.MemoryImage(bytes));
      } catch (_) {
        continue;
      }
    }
    return fotos;
  }

  pw.Widget _lancamentoCardWithPhotos(
    Lancamento l,
    List<pw.MemoryImage> fotos,
  ) {
    final linhas = <String>[
      'Data/hora: ${DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(l.dataHora)}',
      'Betoneira: ${_fallback(l.caminhao)}',
      'Concreteira: ${_fallback(l.concreteira)}',
      'NF: ${_fallback(l.notaFiscal)}',
      'Volume: ${_fmtNum(l.volumeM3, 3)} m³',
      'Dosagem: ${_fmtNum(l.dosagemKgM3, 3)} kg/m³',
      'CWS total: ${_fmtNum(l.cwsTotalKg, 3)} kg',
    ];

    if (l.cwsAdicionadoKg != null) {
      linhas.add('CWS adicionado: ${_fmtNum(l.cwsAdicionadoKg!, 3)} kg');
    }
    if (l.slumpAntes != null) {
      linhas.add('Slump antes: ${_fmtNum(l.slumpAntes!, 1)} cm');
    }
    if (l.slumpDepois != null) {
      linhas.add('Slump depois: ${_fmtNum(l.slumpDepois!, 1)} cm');
    }
    if (l.tempoMisturaMin != null) {
      linhas.add('Tempo de mistura: ${_fmtNum(l.tempoMisturaMin!, 1)} min');
    }
    if (l.observacoes.trim().isNotEmpty) {
      linhas.add('Observações: ${l.observacoes.trim()}');
    }
    if (fotos.isNotEmpty) {
      linhas.add('Fotos anexas: ${fotos.length}');
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          ...linhas.map(
            (linha) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 1.5),
              child: pw.Text(
                _pdfSafe(linha),
                style: const pw.TextStyle(fontSize: 8.6),
              ),
            ),
          ),
          ..._fotoWidgets(fotos),
        ],
      ),
    );
  }

  List<pw.Widget> _fotoWidgets(List<pw.MemoryImage> fotos) {
    if (fotos.isEmpty) return const [];

    final widgets = <pw.Widget>[pw.SizedBox(height: 4)];
    widgets.add(
      pw.Wrap(
        spacing: 4,
        runSpacing: 4,
        children: fotos
            .map(
              (foto) => pw.ClipRRect(
                horizontalRadius: 6,
                verticalRadius: 6,
                child: pw.Image(
                  foto,
                  width: 48,
                  height: 48,
                  fit: pw.BoxFit.cover,
                ),
              ),
            )
            .toList(),
      ),
    );
    return widgets;
  }

  Future<_PdfLogos> _loadLogos() async {
    Future<pw.MemoryImage?> load(String asset) async {
      try {
        final bytes = await rootBundle.load(asset);
        return pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (_) {
        return null;
      }
    }

    return _PdfLogos(
      netherland: await load('assets/logos/netherland.png'),
      cws: await load('assets/logos/cwsadmix.jpg'),
    );
  }

  Future<_PdfFonts> _loadFonts() async {
    final regularBytes = await rootBundle.load(
      'assets/fonts/Roboto-Regular.ttf',
    );
    final boldBytes = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    return _PdfFonts(
      regular: pw.Font.ttf(regularBytes),
      bold: pw.Font.ttf(boldBytes),
    );
  }

  String _safeFile(String value) {
    var out = value.trim();
    if (out.isEmpty) out = 'obra';
    out = out.replaceAll(RegExp(r'[\/\\\:\*\?"<>\|]'), '_');
    out = out.replaceAll(RegExp(r'\s+'), '_');
    return out;
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}';
  }

  String _fallback(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '—' : trimmed;
  }

  String _fmtNum(double value, int casas) {
    return value.toStringAsFixed(casas).replaceAll('.', ',');
  }

  String _pdfSafe(String value) {
    return value.replaceAll('→', '->').replaceAll('—', '-');
  }
}

class _PdfLogos {
  final pw.MemoryImage? netherland;
  final pw.MemoryImage? cws;

  const _PdfLogos({required this.netherland, required this.cws});
}

class _PdfFonts {
  final pw.Font regular;
  final pw.Font bold;

  const _PdfFonts({required this.regular, required this.bold});
}
