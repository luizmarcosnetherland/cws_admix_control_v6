import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../data/models/concretagem_model.dart';
import '../../data/models/lancamento_model.dart';
import '../../data/models/obra_model.dart';
import 'local_storage_service.dart';

class ObraReportPdfService {
  final LocalStorageService _storage = LocalStorageService();
  static const _lancamentoCardWidth = 255.0;
  static const _rastreioPreviewMaxHeight = 400.0;
  static const _rastreioPreviewMaxSidePx = 1800.0;
  static Future<_PdfLogos>? _logosFuture;
  static Future<_PdfFonts>? _fontsFuture;

  Future<String> buildReportPdf({
    required Obra obra,
    required List<Lancamento> lancamentos,
    List<Concretagem> concretagens = const [],
  }) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Geracao de arquivo local PDF nao esta disponivel no navegador.',
      );
    }

    final bytes = await buildReportPdfBytes(
      obra: obra,
      lancamentos: lancamentos,
      concretagens: concretagens,
    );

    await _storage.ensureBaseStructure();
    final filePath = await _storage.exportFilePath(
      'Relatorio_Obra_${_safeFile(obra.nome)}_${_timestamp()}.pdf',
    );
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<Uint8List> buildReportPdfBytes({
    required Obra obra,
    required List<Lancamento> lancamentos,
    List<Concretagem> concretagens = const [],
  }) async {
    final doc = pw.Document();
    final logos = await _loadLogos();
    final fonts = await _loadFonts();
    final concretagensNormalizadas = _normalizarConcretagens(
      concretagens,
      lancamentos,
    );
    final lancamentosPorConcretagem = _groupLancamentosByConcretagem(
      lancamentos,
    );
    final concretagemSections = await _buildConcretagemSections(
      concretagensNormalizadas,
      lancamentosPorConcretagem,
    );
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
        header: (_) => _pageHeader(
          logos: logos,
          obra: obra,
          generatedAtLabel: generatedAtLabel,
        ),
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
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Flexible(
                flex: 3,
                child: _infoCard('Obra', [
                  _kv('Cliente', _fallback(obra.cliente)),
                  _kv('Local', _fallback(obra.local)),
                  _kv(
                    'Localizacao da obra',
                    _fallback(obra.localizacaoDescricao),
                  ),
                  if (obra.latitude != null && obra.longitude != null)
                    _kv(
                      'Coordenadas',
                      '${obra.latitude!.toStringAsFixed(6)}, ${obra.longitude!.toStringAsFixed(6)}',
                    ),
                  _kv('Responsavel', _fallback(obra.responsavel)),
                  _kv('E-mail engenheiro', _fallback(obra.emailEngenheiro)),
                ]),
              ),
              pw.SizedBox(width: 12),
              pw.Flexible(
                flex: 2,
                child: _infoCard('Resumo', [
                  _kv('Concretagens', '${concretagensNormalizadas.length}'),
                  _kv('Lancamentos', '${lancamentos.length}'),
                  _kv('Volume total', '${_fmtNum(volumeTotal, 1)} m³'),
                  _kv('CWS total', '${_fmtNum(cwsTotal, 1)} kg'),
                  _kv(
                    'Cura umida recomendada ate',
                    curaUmidaAte == null
                        ? '-'
                        : DateFormat(
                            'dd/MM/yyyy',
                            'pt_BR',
                          ).format(curaUmidaAte),
                  ),
                ]),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          _sectionTitle('Concretagens e lançamentos'),
          if (concretagemSections.isEmpty)
            _emptySectionCard('Nenhuma concretagem cadastrada.')
          else
            ...concretagemSections,
        ],
      ),
    );
    return Uint8List.fromList(await doc.save());
  }

  pw.Widget _pageHeader({
    required _PdfLogos logos,
    required Obra obra,
    required String generatedAtLabel,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (logos.netherland != null)
              pw.Image(logos.netherland!, height: 34)
            else
              pw.SizedBox(),
            if (logos.cws != null) pw.Image(logos.cws!, height: 34),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          _pdfSafe('Relatório da obra ${obra.nome}'),
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          _pdfSafe('Gerado em $generatedAtLabel'),
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Divider(),
        pw.SizedBox(height: 6),
      ],
    );
  }

  Future<void> shareReportPdf({
    required Obra obra,
    required List<Lancamento> lancamentos,
    List<Concretagem> concretagens = const [],
    ui.Rect? sharePositionOrigin,
  }) async {
    final filename =
        'Relatorio_Obra_${_safeFile(obra.nome)}_${_timestamp()}.pdf';

    if (kIsWeb) {
      final bytes = await buildReportPdfBytes(
        obra: obra,
        lancamentos: lancamentos,
        concretagens: concretagens,
      );

      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'application/pdf', name: filename)],
        text: 'Relatório em PDF da obra ${obra.nome}',
        subject: 'Relatório da obra ${obra.nome}',
        sharePositionOrigin: sharePositionOrigin,
      );
      return;
    }

    final path = await buildReportPdf(
      obra: obra,
      lancamentos: lancamentos,
      concretagens: concretagens,
    );

    await Share.shareXFiles(
      [XFile(path, name: filename)],
      text: 'Relatório em PDF da obra ${obra.nome}',
      subject: 'Relatório da obra ${obra.nome}',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  Future<String> buildConcretagemReportPdf({
    required Obra obra,
    required Concretagem concretagem,
    required List<Lancamento> lancamentos,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Geracao de arquivo local PDF nao esta disponivel no navegador.',
      );
    }

    final bytes = await buildConcretagemReportPdfBytes(
      obra: obra,
      concretagem: concretagem,
      lancamentos: lancamentos,
    );

    await _storage.ensureBaseStructure();
    final filePath = await _storage.exportFilePath(
      _concretagemReportFilename(obra, concretagem),
    );
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<Uint8List> buildConcretagemReportPdfBytes({
    required Obra obra,
    required Concretagem concretagem,
    required List<Lancamento> lancamentos,
  }) async {
    final doc = pw.Document();
    final logos = await _loadLogos();
    final fonts = await _loadFonts();
    final lancamentosOrdenados = List<Lancamento>.from(lancamentos)
      ..sort((a, b) => a.dataHora.compareTo(b.dataHora));
    final lancamentoCards = await _buildLancamentoCards(lancamentosOrdenados);
    final rastreioPreview = await _loadConcretagemRastreioPreview(
      concretagem,
      lancamentosOrdenados,
    );
    final generatedAtLabel = DateFormat(
      'dd/MM/yyyy HH:mm',
      'pt_BR',
    ).format(DateTime.now());
    final volumeTotal = lancamentosOrdenados.fold<double>(
      0,
      (total, item) => total + item.volumeM3,
    );
    final cwsTotal = lancamentosOrdenados.fold<double>(
      0,
      (total, item) => total + item.cwsTotalKg,
    );
    final primeiroLancamento = lancamentosOrdenados.isEmpty
        ? null
        : lancamentosOrdenados.first.dataHora;
    final ultimoLancamento = lancamentosOrdenados.isEmpty
        ? null
        : lancamentosOrdenados.last.dataHora;
    final curaUmidaAte = ultimoLancamento?.add(const Duration(days: 7));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
        header: (_) => _concretagemPageHeader(
          logos: logos,
          obra: obra,
          concretagem: concretagem,
          generatedAtLabel: generatedAtLabel,
        ),
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
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Flexible(
                flex: 3,
                child: _infoCard('Obra', [
                  _kv('Nome', _fallback(obra.nome)),
                  _kv('Cliente', _fallback(obra.cliente)),
                  _kv('Local', _fallback(obra.local)),
                  _kv(
                    'Localizacao da obra',
                    _fallback(obra.localizacaoDescricao),
                  ),
                  if (obra.latitude != null && obra.longitude != null)
                    _kv(
                      'Coordenadas',
                      '${obra.latitude!.toStringAsFixed(6)}, ${obra.longitude!.toStringAsFixed(6)}',
                    ),
                  _kv('Responsavel', _fallback(obra.responsavel)),
                  _kv('E-mail engenheiro', _fallback(obra.emailEngenheiro)),
                ]),
              ),
              pw.SizedBox(width: 12),
              pw.Flexible(
                flex: 2,
                child: _infoCard('Concretagem', [
                  _kv(
                    'Estrutura',
                    concretagem.estruturaConcretada.trim().isEmpty
                        ? 'nao informada'
                        : concretagem.estruturaConcretada.trim(),
                  ),
                  _kv(
                    'Concreteira',
                    _fallbackNaoInformada(concretagem.concreteira),
                  ),
                  _kv(
                    'Controle tecnologico',
                    _controleTecnologicoLabel(concretagem.controleTecnologico),
                  ),
                  _kv(
                    'Empresa tecnologia',
                    _empresaTecnologiaLabelConcretagem(concretagem),
                  ),
                  _kv('Lancamentos', '${lancamentosOrdenados.length}'),
                  _kv('Volume total', '${_fmtNum(volumeTotal, 1)} m³'),
                  _kv('CWS total', '${_fmtNum(cwsTotal, 1)} kg'),
                  _kv(
                    'Primeiro lancamento',
                    primeiroLancamento == null
                        ? '-'
                        : DateFormat(
                            'dd/MM/yyyy HH:mm',
                            'pt_BR',
                          ).format(primeiroLancamento),
                  ),
                  _kv(
                    'Ultimo lancamento',
                    ultimoLancamento == null
                        ? '-'
                        : DateFormat(
                            'dd/MM/yyyy HH:mm',
                            'pt_BR',
                          ).format(ultimoLancamento),
                  ),
                  _kv(
                    'Cura umida recomendada ate',
                    curaUmidaAte == null
                        ? '-'
                        : DateFormat(
                            'dd/MM/yyyy',
                            'pt_BR',
                          ).format(curaUmidaAte),
                  ),
                ]),
              ),
            ],
          ),
          if (rastreioPreview != null) ...[
            pw.SizedBox(height: 12),
            _buildConcretagemRastreioBlock(
              rastreioPreview: rastreioPreview,
              lancamentos: lancamentosOrdenados,
            ),
          ],
          pw.SizedBox(height: 12),
          _sectionTitle('Lançamentos da concretagem'),
          if (lancamentoCards.isEmpty)
            _emptySectionCard('Nenhum lançamento cadastrado nesta concretagem.')
          else
            pw.Wrap(spacing: 8, runSpacing: 8, children: lancamentoCards),
        ],
      ),
    );

    return Uint8List.fromList(await doc.save());
  }

  Future<void> shareConcretagemReportPdf({
    required Obra obra,
    required Concretagem concretagem,
    required List<Lancamento> lancamentos,
    ui.Rect? sharePositionOrigin,
  }) async {
    final filename = _concretagemReportFilename(obra, concretagem);
    final assunto =
        'Relatório da concretagem ${_concretagemReportLabel(concretagem)}';
    final texto = '$assunto - obra ${obra.nome}';

    if (kIsWeb) {
      final bytes = await buildConcretagemReportPdfBytes(
        obra: obra,
        concretagem: concretagem,
        lancamentos: lancamentos,
      );

      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'application/pdf', name: filename)],
        text: texto,
        subject: assunto,
        sharePositionOrigin: sharePositionOrigin,
      );
      return;
    }

    final path = await buildConcretagemReportPdf(
      obra: obra,
      concretagem: concretagem,
      lancamentos: lancamentos,
    );

    await Share.shareXFiles(
      [XFile(path, name: filename)],
      text: texto,
      subject: assunto,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  pw.Widget _concretagemPageHeader({
    required _PdfLogos logos,
    required Obra obra,
    required Concretagem concretagem,
    required String generatedAtLabel,
  }) {
    final titulo = _concretagemReportLabel(concretagem);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (logos.netherland != null)
              pw.Image(logos.netherland!, height: 34)
            else
              pw.SizedBox(),
            if (logos.cws != null) pw.Image(logos.cws!, height: 34),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          _pdfSafe('Relatório da concretagem - $titulo'),
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          _pdfSafe('Obra: ${obra.nome}'),
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Text(
          _pdfSafe('Gerado em $generatedAtLabel'),
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Divider(),
        pw.SizedBox(height: 6),
      ],
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

  pw.Widget _infoCard(String title, List<pw.Widget> children) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [_sectionTitle(title), ...children],
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

  pw.Widget _emptySectionCard(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(_pdfSafe(text), style: const pw.TextStyle(fontSize: 10)),
    );
  }

  Map<int, List<Lancamento>> _groupLancamentosByConcretagem(
    List<Lancamento> lancamentos,
  ) {
    final grouped = <int, List<Lancamento>>{};
    for (final lancamento in lancamentos) {
      grouped.putIfAbsent(lancamento.concretagemId, () => []).add(lancamento);
    }
    return grouped;
  }

  List<Concretagem> _normalizarConcretagens(
    List<Concretagem> concretagens,
    List<Lancamento> lancamentos,
  ) {
    final origem = concretagens.isNotEmpty
        ? concretagens
        : _concretagensDerivadasDosLancamentos(lancamentos);
    final normalizadas = List<Concretagem>.from(origem);
    normalizadas.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return normalizadas;
  }

  List<Concretagem> _concretagensDerivadasDosLancamentos(
    List<Lancamento> lancamentos,
  ) {
    final derivadas = <int, Concretagem>{};
    for (final lancamento in lancamentos) {
      derivadas.putIfAbsent(
        lancamento.concretagemId,
        () => Concretagem(
          id: lancamento.concretagemId,
          obraId: lancamento.obraId,
          estruturaConcretada: lancamento.estruturaConcretada,
          concreteira: lancamento.concreteira,
          controleTecnologico: lancamento.controleTecnologico,
          empresaTecnologiaConcreto: lancamento.empresaTecnologiaConcreto,
          createdAt: lancamento.createdAt,
          updatedAt: lancamento.updatedAt,
        ),
      );
    }
    return derivadas.values.toList(growable: false);
  }

  Future<List<pw.Widget>> _buildConcretagemSections(
    List<Concretagem> concretagens,
    Map<int, List<Lancamento>> lancamentosPorConcretagem,
  ) async {
    final sections = <pw.Widget>[];
    for (var index = 0; index < concretagens.length; index++) {
      if (index > 0) {
        sections.add(pw.SizedBox(height: 12));
      }

      final concretagem = concretagens[index];
      final lancamentos =
          lancamentosPorConcretagem[concretagem.id] ?? const <Lancamento>[];
      final lancamentoCards = await _buildLancamentoCards(lancamentos);
      final rastreioPreview = await _loadConcretagemRastreioPreview(
        concretagem,
        lancamentos,
      );

      sections.add(
        _buildConcretagemCard(
          concretagem: concretagem,
          lancamentos: lancamentos,
          index: index,
        ),
      );
      if (rastreioPreview != null) {
        sections.add(pw.SizedBox(height: 8));
        sections.add(
          _buildConcretagemRastreioBlock(
            rastreioPreview: rastreioPreview,
            lancamentos: lancamentos,
          ),
        );
      }
      sections.add(pw.SizedBox(height: 8));
      sections.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 2, bottom: 6),
          child: pw.Text(
            'Lançamentos desta concretagem',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ),
      );
      sections.add(
        lancamentoCards.isEmpty
            ? _emptySectionCard(
                'Nenhum lançamento cadastrado nesta concretagem.',
              )
            : pw.Wrap(spacing: 8, runSpacing: 8, children: lancamentoCards),
      );
    }

    return sections;
  }

  pw.Widget _buildConcretagemCard({
    required Concretagem concretagem,
    required List<Lancamento> lancamentos,
    required int index,
  }) {
    final volumeTotal = lancamentos.fold<double>(
      0,
      (total, item) => total + item.volumeM3,
    );
    final cwsTotal = lancamentos.fold<double>(
      0,
      (total, item) => total + item.cwsTotalKg,
    );
    final ultimoLancamento = lancamentos.isEmpty
        ? null
        : lancamentos
              .map((item) => item.dataHora)
              .reduce((a, b) => a.isAfter(b) ? a : b);

    return _infoCard('Concretagem ${index + 1}', [
      _kv(
        'Estrutura',
        concretagem.estruturaConcretada.trim().isEmpty
            ? 'nao informada'
            : concretagem.estruturaConcretada.trim(),
      ),
      _kv('Concreteira', _fallbackNaoInformada(concretagem.concreteira)),
      _kv(
        'Controle tecnologico',
        _controleTecnologicoLabel(concretagem.controleTecnologico),
      ),
      _kv(
        'Empresa tecnologia',
        _empresaTecnologiaLabelConcretagem(concretagem),
      ),
      _kv('Lancamentos', '${lancamentos.length}'),
      _kv('Volume total', '${_fmtNum(volumeTotal, 1)} m³'),
      _kv('CWS total', '${_fmtNum(cwsTotal, 1)} kg'),
      _kv(
        'Ultimo lancamento',
        ultimoLancamento == null
            ? '-'
            : DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(ultimoLancamento),
      ),
    ]);
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

  Future<_ConcretagemRastreioPreview?> _loadConcretagemRastreioPreview(
    Concretagem concretagem,
    List<Lancamento> lancamentos,
  ) async {
    final plantaPath = concretagem.plantaPath.trim();
    if (plantaPath.isEmpty) return null;

    final file = File(plantaPath);
    if (!await file.exists()) return null;

    try {
      final sourceBytes = await file.readAsBytes();
      if (sourceBytes.isEmpty) return null;

      final idsValidos = lancamentos
          .map((item) => item.id)
          .whereType<int>()
          .toSet();
      final tracos = concretagem.rastreioTracos
          .where((item) => idsValidos.contains(item.lancamentoId))
          .where((item) => item.points.length >= 2)
          .toList(growable: false);

      final rendered = await _renderConcretagemRastreioPreview(
        sourceBytes,
        tracos,
      );
      return _ConcretagemRastreioPreview(
        image: pw.MemoryImage(rendered.bytes),
        aspectRatio: rendered.aspectRatio,
        lancamentosMarcados: tracos
            .map((item) => item.lancamentoId)
            .toSet()
            .toList(growable: false),
      );
    } catch (_) {
      return null;
    }
  }

  Future<_RenderedRastreioPreview> _renderConcretagemRastreioPreview(
    Uint8List sourceBytes,
    List<ConcretagemRastreioTraco> tracos,
  ) async {
    final codec = await ui.instantiateImageCodec(sourceBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final originalWidth = image.width.toDouble();
    final originalHeight = image.height == 0 ? 1.0 : image.height.toDouble();
    final aspectRatio = originalWidth / originalHeight;

    final maxSide = math.max(originalWidth, originalHeight);
    final scale = maxSide > _rastreioPreviewMaxSidePx
        ? (_rastreioPreviewMaxSidePx / maxSide)
        : 1.0;
    final targetWidth = math.max(1, (originalWidth * scale).round());
    final targetHeight = math.max(1, (originalHeight * scale).round());

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
    );
    final targetRect = ui.Rect.fromLTWH(
      0,
      0,
      targetWidth.toDouble(),
      targetHeight.toDouble(),
    );

    canvas.drawRect(targetRect, ui.Paint()..color = const ui.Color(0xFFF4F1E8));
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, originalWidth, originalHeight),
      targetRect,
      ui.Paint(),
    );

    for (final traco in tracos) {
      final points = traco.points
          .map((item) => ui.Offset(item.x * targetWidth, item.y * targetHeight))
          .toList(growable: false);
      final brushSize = traco.resolveBrushSize(
        math.min(targetWidth.toDouble(), targetHeight.toDouble()),
      );
      _paintRastreioSpray(
        canvas,
        points,
        _rastreioUiColor(traco.lancamentoId),
        brushSize,
      );
    }

    final picture = recorder.endRecording();
    final renderedImage = await picture.toImage(targetWidth, targetHeight);
    final byteData = await renderedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    image.dispose();
    renderedImage.dispose();

    if (byteData == null) {
      throw Exception('Falha ao renderizar a planta para o PDF.');
    }

    return _RenderedRastreioPreview(
      bytes: byteData.buffer.asUint8List(),
      aspectRatio: aspectRatio,
    );
  }

  void _paintRastreioSpray(
    ui.Canvas canvas,
    List<ui.Offset> points,
    ui.Color color,
    double brushSize,
  ) {
    if (points.length < 2 || brushSize <= 0) return;

    final spacing = brushSize * 0.22;
    final densified = _densifyRastreioPoints(points, spacing);
    final blurPaint = ui.Paint()
      ..style = ui.PaintingStyle.fill
      ..color = color.withValues(alpha: 0.18)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, brushSize * 0.26);
    final corePaint = ui.Paint()
      ..style = ui.PaintingStyle.fill
      ..color = color.withValues(alpha: 0.34);

    for (final point in densified) {
      canvas.drawCircle(point, brushSize * 0.55, blurPaint);
      canvas.drawCircle(point, brushSize * 0.18, corePaint);
    }

    for (final point in points) {
      canvas.drawCircle(point, brushSize * 0.25, corePaint);
    }
  }

  List<ui.Offset> _densifyRastreioPoints(
    List<ui.Offset> points,
    double spacing,
  ) {
    final output = <ui.Offset>[];
    for (var index = 0; index < points.length - 1; index++) {
      final start = points[index];
      final end = points[index + 1];
      output.add(start);

      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final distance = math.sqrt((dx * dx) + (dy * dy));
      if (distance <= spacing) continue;

      final steps = (distance / spacing).floor();
      for (var step = 1; step < steps; step++) {
        final t = step / steps;
        output.add(ui.Offset(start.dx + (dx * t), start.dy + (dy * t)));
      }
    }
    output.add(points.last);
    return output;
  }

  pw.Widget _buildConcretagemRastreioBlock({
    required _ConcretagemRastreioPreview rastreioPreview,
    required List<Lancamento> lancamentos,
  }) {
    final marcados = rastreioPreview.lancamentosMarcados.toSet();

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Planta de rastreio da concretagem',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _pdfSafe(
              marcados.isEmpty
                  ? 'Planta escaneada sem marcações registradas.'
                  : 'Planta ampliada com as marcações realizadas nesta concretagem.',
            ),
            style: const pw.TextStyle(fontSize: 9.2),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            width: double.infinity,
            height: _rastreioPreviewMaxHeight,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F4F1E8'),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            alignment: pw.Alignment.center,
            child: pw.Image(rastreioPreview.image, fit: pw.BoxFit.contain),
          ),
          if (lancamentos.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              'Legenda dos lançamentos',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Wrap(
              spacing: 8,
              runSpacing: 6,
              children: lancamentos
                  .where((item) => item.id != null)
                  .map(
                    (item) => _buildRastreioLegendaItem(
                      lancamento: item,
                      marcado: marcados.contains(item.id),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildRastreioLegendaItem({
    required Lancamento lancamento,
    required bool marcado,
  }) {
    final id = lancamento.id;
    final color = id == null || !marcado
        ? PdfColors.grey500
        : _rastreioPdfColor(id);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            width: 10,
            height: 10,
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Text(
            _pdfSafe(
              '${_legendTitleLancamento(lancamento)}${marcado ? '' : ' - sem marcação'}',
            ),
            style: const pw.TextStyle(fontSize: 8.6),
          ),
        ],
      ),
    );
  }

  pw.Widget _lancamentoCardWithPhotos(
    Lancamento l,
    List<pw.MemoryImage> fotos,
  ) {
    final linhas = <String>[
      'Data/hora: ${DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(l.dataHora)}',
      'Betoneira: ${_fallback(l.caminhao)}',
      'NF: ${_fallback(l.notaFiscal)}',
      'Volume: ${_fmtNum(l.volumeM3, 1)} m³',
      'Dosagem: ${_fmtNum(l.dosagemKgM3, 1)} kg/m³',
      'CWS total: ${_fmtNum(l.cwsTotalKg, 1)} kg',
    ];

    if (l.cwsAdicionadoKg != null) {
      linhas.add('CWS adicionado: ${_fmtNum(l.cwsAdicionadoKg!, 1)} kg');
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
    return _logosFuture ??= () async {
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
    }();
  }

  Future<_PdfFonts> _loadFonts() async {
    return _fontsFuture ??= () async {
      final regularBytes = await rootBundle.load(
        'assets/fonts/Roboto-Regular.ttf',
      );
      final boldBytes = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      return _PdfFonts(
        regular: pw.Font.ttf(regularBytes),
        bold: pw.Font.ttf(boldBytes),
      );
    }();
  }

  String _safeFile(String value) {
    var out = value.trim();
    if (out.isEmpty) out = 'obra';
    out = out.replaceAll(RegExp(r'[\/\\\:\*\?"<>\|]'), '_');
    out = out.replaceAll(RegExp(r'\s+'), '_');
    return out;
  }

  String _concretagemReportLabel(Concretagem concretagem) {
    final estrutura = concretagem.estruturaConcretada.trim();
    if (estrutura.isNotEmpty) return estrutura;
    if (concretagem.id != null) return 'Concretagem ${concretagem.id}';
    return 'Concretagem';
  }

  String _concretagemReportFilename(Obra obra, Concretagem concretagem) {
    return 'Relatorio_Concretagem_${_safeFile(obra.nome)}_${_safeFile(_concretagemReportLabel(concretagem))}_${_timestamp()}.pdf';
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

  String _fallbackNaoInformada(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'nao informada' : trimmed;
  }

  String _controleTecnologicoLabel(String value) {
    return value.trim().toLowerCase() == 'sim' ? 'Sim' : 'nao informado';
  }

  String _empresaTecnologiaLabelConcretagem(Concretagem concretagem) {
    if (concretagem.controleTecnologico.trim().toLowerCase() != 'sim') {
      return 'nao informada';
    }
    return _fallbackNaoInformada(concretagem.empresaTecnologiaConcreto);
  }

  String _fmtNum(double value, int casas) {
    return value.toStringAsFixed(casas).replaceAll('.', ',');
  }

  String _legendTitleLancamento(Lancamento lancamento) {
    final titulo = lancamento.caminhao.trim().isEmpty
        ? 'Lançamento ${lancamento.id ?? ''}'.trim()
        : lancamento.caminhao.trim();
    final dataHora = DateFormat(
      'dd/MM HH:mm',
      'pt_BR',
    ).format(lancamento.dataHora);
    return '$titulo • $dataHora • ${_fmtNum(lancamento.volumeM3, 1)} m³';
  }

  ui.Color _rastreioUiColor(int lancamentoId) {
    final value =
        _rastreioPalette[lancamentoId.abs() % _rastreioPalette.length];
    return ui.Color(value);
  }

  PdfColor _rastreioPdfColor(int lancamentoId) {
    final value =
        _rastreioPalette[lancamentoId.abs() % _rastreioPalette.length];
    final hex = value.toRadixString(16).padLeft(8, '0').substring(2);
    return PdfColor.fromHex('#$hex');
  }

  String _pdfSafe(String value) {
    return value.replaceAll('→', '->').replaceAll('—', '-');
  }

  static const _rastreioPalette = <int>[
    0xFFE07A5F,
    0xFF3D405B,
    0xFF81B29A,
    0xFFF2CC8F,
    0xFF6D597A,
    0xFF2A9D8F,
    0xFFC8553D,
    0xFF4D908E,
  ];
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

class _ConcretagemRastreioPreview {
  final pw.MemoryImage image;
  final double aspectRatio;
  final List<int> lancamentosMarcados;

  const _ConcretagemRastreioPreview({
    required this.image,
    required this.aspectRatio,
    required this.lancamentosMarcados,
  });
}

class _RenderedRastreioPreview {
  final Uint8List bytes;
  final double aspectRatio;

  const _RenderedRastreioPreview({
    required this.bytes,
    required this.aspectRatio,
  });
}
