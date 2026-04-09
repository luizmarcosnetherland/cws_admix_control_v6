import '../local/app_database.dart';
import '../models/lancamento_model.dart';

class ResumoLancamentosObra {
  final int quantidade;
  final double volumeTotalM3;
  final double cwsTotalKg;

  const ResumoLancamentosObra({
    required this.quantidade,
    required this.volumeTotalM3,
    required this.cwsTotalKg,
  });
}

class LancamentoRepository {
  final AppDatabase _db = AppDatabase.instance;

  Future<List<Lancamento>> listarPorObra(
    int obraId, {
    DateTime? inicio,
    DateTime? fimExclusivo,
  }) async {
    final db = await _db.database;

    final where = <String>['obra_id = ?'];
    final args = <Object>[obraId];

    if (inicio != null) {
      where.add('data_hora >= ?');
      args.add(inicio.toIso8601String());
    }
    if (fimExclusivo != null) {
      where.add('data_hora < ?');
      args.add(fimExclusivo.toIso8601String());
    }

    final rows = await db.rawQuery('''
      SELECT
        l.id,
        l.obra_id,
        l.concretagem_id,
        l.data_hora,
        l.caminhao,
        COALESCE(c.estrutura_concretada, l.estrutura_concretada, '') AS estrutura_concretada,
        COALESCE(c.concreteira, l.concreteira, '') AS concreteira,
        COALESCE(c.controle_tecnologico, l.controle_tecnologico, '') AS controle_tecnologico,
        COALESCE(c.empresa_tecnologia_concreto, l.empresa_tecnologia_concreto, '') AS empresa_tecnologia_concreto,
        l.volume_m3,
        l.dosagem_kg_m3,
        l.cws_total_kg,
        l.cws_adicionado_kg,
        l.dosagem_de_acordo,
        l.nota_fiscal,
        l.slump_antes,
        l.slump_depois,
        l.tempo_mistura_min,
        l.observacoes,
        l.foto_paths,
        l.created_at,
        l.updated_at
      FROM lancamentos l
      LEFT JOIN concretagens c ON c.id = l.concretagem_id
      WHERE ${where.join(' AND ')}
      ORDER BY l.data_hora DESC
    ''', args);

    return rows
        .map((e) => Lancamento.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Lancamento>> listarPorConcretagem(int concretagemId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        l.id,
        l.obra_id,
        l.concretagem_id,
        l.data_hora,
        l.caminhao,
        COALESCE(c.estrutura_concretada, l.estrutura_concretada, '') AS estrutura_concretada,
        COALESCE(c.concreteira, l.concreteira, '') AS concreteira,
        COALESCE(c.controle_tecnologico, l.controle_tecnologico, '') AS controle_tecnologico,
        COALESCE(c.empresa_tecnologia_concreto, l.empresa_tecnologia_concreto, '') AS empresa_tecnologia_concreto,
        l.volume_m3,
        l.dosagem_kg_m3,
        l.cws_total_kg,
        l.cws_adicionado_kg,
        l.dosagem_de_acordo,
        l.nota_fiscal,
        l.slump_antes,
        l.slump_depois,
        l.tempo_mistura_min,
        l.observacoes,
        l.foto_paths,
        l.created_at,
        l.updated_at
      FROM lancamentos l
      LEFT JOIN concretagens c ON c.id = l.concretagem_id
      WHERE l.concretagem_id = ?
      ORDER BY l.data_hora DESC
    ''',
      [concretagemId],
    );

    return rows
        .map((e) => Lancamento.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<int> criarLancamento({
    required int obraId,
    required int concretagemId,
    required DateTime dataHora,
    required String caminhao,
    String estruturaConcretada = '',
    String concreteira = '',
    String controleTecnologico = '',
    String empresaTecnologiaConcreto = '',
    required double volumeM3,
    double dosagemKgM3 = 0.80,
    String observacoes = '',
    List<String> fotoPaths = const [],
    String notaFiscal = '',
    double? cwsAdicionadoKg,
    double? slumpAntes,
    double? slumpDepois,
    double? tempoMisturaMin,
  }) async {
    final db = await _db.database;
    final now = DateTime.now();
    final concretagem = await db.query(
      'concretagens',
      where: 'id = ?',
      whereArgs: [concretagemId],
      limit: 1,
    );
    final concretagemMap = concretagem.isEmpty
        ? const <String, Object?>{}
        : Map<String, Object?>.from(concretagem.first);

    final volume = _round1(volumeM3);
    final dosagem = _round1(dosagemKgM3);
    final cwsTotal = _round1(volume * dosagem);
    final cwsAdd = cwsAdicionadoKg == null ? null : _round1(cwsAdicionadoKg);

    final dosagemAcordo = _calcDosagemDeAcordo(
      volumeM3: volume,
      dosagemKgM3: dosagem,
      cwsAdicionadoKg: cwsAdd,
    );
    final lancamento = Lancamento(
      obraId: obraId,
      concretagemId: concretagemId,
      dataHora: dataHora,
      caminhao: caminhao.trim(),
      estruturaConcretada:
          ((concretagemMap['estrutura_concretada'] as String?) ??
                  estruturaConcretada)
              .trim(),
      concreteira: ((concretagemMap['concreteira'] as String?) ?? concreteira)
          .trim(),
      controleTecnologico:
          ((concretagemMap['controle_tecnologico'] as String?) ??
                  controleTecnologico)
              .trim(),
      empresaTecnologiaConcreto:
          ((concretagemMap['empresa_tecnologia_concreto'] as String?) ??
                  empresaTecnologiaConcreto)
              .trim(),
      volumeM3: volume,
      dosagemKgM3: dosagem,
      cwsTotalKg: cwsTotal,
      cwsAdicionadoKg: cwsAdd,
      dosagemDeAcordo: dosagemAcordo,
      notaFiscal: notaFiscal.trim(),
      slumpAntes: slumpAntes,
      slumpDepois: slumpDepois,
      tempoMisturaMin: tempoMisturaMin,
      observacoes: observacoes.trim(),
      fotoPaths: fotoPaths,
      createdAt: now,
      updatedAt: now,
    );

    return db.insert('lancamentos', lancamento.toMap()..remove('id'));
  }

  int? _calcDosagemDeAcordo({
    required double volumeM3,
    required double dosagemKgM3,
    required double? cwsAdicionadoKg,
  }) {
    if (cwsAdicionadoKg == null) return null;
    if (volumeM3 <= 0 || dosagemKgM3 <= 0) return null;

    final esperado = volumeM3 * dosagemKgM3;
    final diff = (cwsAdicionadoKg - esperado).abs();

    final tol2pct = esperado * 0.02;
    final tol = tol2pct < 0.2 ? 0.2 : tol2pct;

    return diff <= tol ? 1 : 0;
  }

  Future<int> atualizarLancamento(Lancamento lancamento) async {
    final db = await _db.database;

    final volume = _round1(lancamento.volumeM3);
    final dosagem = _round1(lancamento.dosagemKgM3);
    final cwsTotal = _round1(volume * dosagem);

    final updatedBase = lancamento.copyWith(
      volumeM3: volume,
      dosagemKgM3: dosagem,
      cwsTotalKg: cwsTotal,
      updatedAt: DateTime.now(),
    );

    final dosagemAcordo = _calcDosagemDeAcordo(
      volumeM3: updatedBase.volumeM3,
      dosagemKgM3: updatedBase.dosagemKgM3,
      cwsAdicionadoKg: updatedBase.cwsAdicionadoKg,
    );

    final updated = updatedBase.copyWith(dosagemDeAcordo: dosagemAcordo);
    return db.update(
      'lancamentos',
      updated.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [lancamento.id],
    );
  }

  Future<int> excluirLancamento(int id) async {
    final db = await _db.database;

    return db.delete('lancamentos', where: 'id = ?', whereArgs: [id]);
  }

  Future<ResumoLancamentosObra> resumoPorObra(
    int obraId, {
    DateTime? inicio,
    DateTime? fimExclusivo,
  }) async {
    final db = await _db.database;

    final where = <String>['obra_id = ?'];
    final args = <Object>[obraId];

    if (inicio != null) {
      where.add('data_hora >= ?');
      args.add(inicio.toIso8601String());
    }
    if (fimExclusivo != null) {
      where.add('data_hora < ?');
      args.add(fimExclusivo.toIso8601String());
    }

    final rows = await db.rawQuery('''
      SELECT
        COUNT(*) AS qtd,
        COALESCE(SUM(volume_m3), 0) AS volume_total,
        COALESCE(SUM(cws_total_kg), 0) AS cws_total
      FROM lancamentos
      WHERE ${where.join(' AND ')}
    ''', args);

    final row = rows.first;
    return ResumoLancamentosObra(
      quantidade: (row['qtd'] as num).toInt(),
      volumeTotalM3: ((row['volume_total'] as num?) ?? 0).toDouble(),
      cwsTotalKg: ((row['cws_total'] as num?) ?? 0).toDouble(),
    );
  }

  double _round1(double value) => (value * 10).roundToDouble() / 10;
}
