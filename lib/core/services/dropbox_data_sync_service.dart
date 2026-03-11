import 'dart:convert';
import 'dart:io';

import '../../data/models/obra_model.dart';
import '../../data/repositories/lancamento_repository.dart';
import '../../data/repositories/obra_repository.dart';
import 'local_dropbox_storage_service.dart';

class DropboxDataSyncService {
  final ObraRepository _obraRepo = ObraRepository();
  final LancamentoRepository _lancRepo = LancamentoRepository();
  final LocalDropboxStorageService _storage = LocalDropboxStorageService();

  Future<String> syncAllToDropbox() async {
    final snapshot = await _buildSnapshot();
    final file = await _writeSnapshotToLocalDropbox(snapshot);
    final latestPath = await _storage.dataFilePath('latest.json');
    final latestFile = File(latestPath);
    await latestFile.writeAsBytes(await file.readAsBytes(), flush: true);
    return file.path;
  }

  Future<Map<String, dynamic>> _buildSnapshot() async {
    final ativas = await _obraRepo.listarObrasAtivas();
    final arquivadas = await _obraRepo.listarObrasArquivadas();
    final obras = <Obra>[...ativas, ...arquivadas];

    final obrasJson = <Map<String, dynamic>>[];

    for (final obra in obras) {
      final obraId = obra.id;
      if (obraId == null) continue;

      final lancs = await _lancRepo.listarPorObra(obraId);

      obrasJson.add({
        'id': obra.id,
        'nome': obra.nome,
        'cliente': obra.cliente,
        'local': obra.local,
        'responsavel': obra.responsavel,
        'email_engenheiro': obra.emailEngenheiro,
        'observacoes': obra.observacoes,
        'ativo': obra.ativo,
        'created_at': obra.createdAt.toIso8601String(),
        'updated_at': obra.updatedAt.toIso8601String(),
        'lancamentos': lancs.map((l) {
          return {
            'id': l.id,
            'obra_id': l.obraId,
            'data_hora': l.dataHora.toIso8601String(),
            'betoneira': l.caminhao,
            'concreteira': l.concreteira,
            'volume_m3': l.volumeM3,
            'dosagem_kg_m3': l.dosagemKgM3,
            'cws_total_kg': l.cwsTotalKg,
            'nota_fiscal': l.notaFiscal,
            'slump_antes': l.slumpAntes,
            'slump_depois': l.slumpDepois,
            'tempo_mistura_min': l.tempoMisturaMin,
            'observacoes': l.observacoes,
            'created_at': l.createdAt.toIso8601String(),
            'updated_at': l.updatedAt.toIso8601String(),
          };
        }).toList(),
      });
    }

    return {
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'obrasCount': obras.length,
      'obras': obrasJson,
    };
  }

  Future<File> _writeSnapshotToLocalDropbox(
    Map<String, dynamic> snapshot,
  ) async {
    await _storage.ensureBaseStructure();
    final name = 'snapshot_${_timestamp()}.json';
    final path = await _storage.snapshotFilePath(name);

    final jsonStr = const JsonEncoder.withIndent('  ').convert(snapshot);
    final bytes = utf8.encode('\ufeff$jsonStr'); // BOM (Excel/editores)

    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}
