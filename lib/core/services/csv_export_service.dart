import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;

import '../../data/models/lancamento_model.dart';
import '../../data/models/obra_model.dart';
import '../../data/repositories/lancamento_repository.dart';
import 'local_dropbox_storage_service.dart';

class CsvExportService {
  final LancamentoRepository _repo = LancamentoRepository();
  final LocalDropboxStorageService _storage = LocalDropboxStorageService();

  /// Mantido por compatibilidade: exporta TODOS os lançamentos da obra.
  Future<String> exportLancamentosObraToDownloads({required Obra obra}) async {
    final obraId = obra.id;
    if (obraId == null) throw Exception('Obra sem ID (não persistida).');

    final lancamentos = await _repo.listarPorObra(obraId);
    return exportLancamentosToDownloads(
      obra: obra,
      lancamentos: lancamentos,
      exportLabel: 'todos',
    );
  }

  /// Novo: exporta UMA LISTA já filtrada/ordenada (exatamente como está na tela).
  Future<String> exportLancamentosToDownloads({
    required Obra obra,
    required List<Lancamento> lancamentos,
    String exportLabel = 'filtrado',
  }) async {
    final rows = <List<String>>[];

    rows.add([
      'Obra',
      'Cliente',
      'Local',
      'Responsável',
      'Data/Hora',
      'Betoneira (nº/placa)',
      'Concreteira',
      'NF',
      'Slump antes (cm)',
      'Slump depois (cm)',
      'Tempo mistura (min)',
      'Volume (m³)',
      'Dosagem (kg/m³)',
      'CWS Total (kg)',
      'CWS adicionado (kg)',
      'Dosagem de acordo',
      'Observações',
    ]);

    for (final l in lancamentos) {
      rows.add([
        obra.nome,
        obra.cliente,
        obra.local,
        obra.responsavel,
        _fmtDataHora(l.dataHora),
        l.caminhao,
        l.concreteira,
        l.notaFiscal,
        l.slumpAntes == null ? '' : _fmtNum(l.slumpAntes!, casas: 1),
        l.slumpDepois == null ? '' : _fmtNum(l.slumpDepois!, casas: 1),
        l.tempoMisturaMin == null ? '' : _fmtNum(l.tempoMisturaMin!, casas: 1),
        _fmtNum(l.volumeM3, casas: 1),
        _fmtNum(l.dosagemKgM3, casas: 1),
        _fmtNum(l.cwsTotalKg, casas: 1),
        l.cwsAdicionadoKg == null ? '' : _fmtNum(l.cwsAdicionadoKg!, casas: 1),
        l.dosagemDeAcordo == null
            ? ''
            : (l.dosagemDeAcordo == 1 ? 'OK' : 'DIVERGENTE'),
        l.observacoes,
      ]);
    }

    final csv = const ListToCsvConverter(
      fieldDelimiter: ';',
      textDelimiter: '"',
      eol: '\n',
    ).convert(rows);

    await _storage.ensureBaseStructure();
    final exportDir = await _storage.exportsDir;
    await exportDir.create(recursive: true);

    final fileName =
        'CWS_${_safeFile(obra.nome)}_${_safeFile(exportLabel)}_${_timestamp()}.csv';
    final filePath = p.join(exportDir.path, fileName);

    // BOM UTF-8 para Excel abrir acentos OK
    final bytes = utf8.encode('\ufeff$csv');
    await File(filePath).writeAsBytes(bytes, flush: true);

    return filePath;
  }

  String _safeFile(String s) {
    var out = s.trim();
    if (out.isEmpty) out = 'x';
    out = out.replaceAll(RegExp(r'[\/\\\:\*\?"<>\|]'), '_');
    out = out.replaceAll(RegExp(r'\s+'), '_');
    if (out.length > 60) out = out.substring(0, 60);
    return out;
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  String _fmtDataHora(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _fmtNum(double v, {int casas = 1}) {
    return v.toStringAsFixed(casas).replaceAll('.', ',');
  }
}
