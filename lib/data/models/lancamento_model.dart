import 'dart:convert';

class Lancamento {
  final int? id;
  final int obraId;
  final DateTime dataHora;

  /// Vamos usar como "Betoneira (nº/placa)" na UI, mantendo o nome antigo no banco.
  final String caminhao;

  final String estruturaConcretada;
  final String concreteira;
  final String controleTecnologico;
  final String empresaTecnologiaConcreto;
  final double volumeM3;
  final double dosagemKgM3;
  final double cwsTotalKg;
  final double? cwsAdicionadoKg;
  final int? dosagemDeAcordo; // 1 = ok, 0 = divergente, null = não informado

  final String notaFiscal;
  final double? slumpAntes;
  final double? slumpDepois;
  final double? tempoMisturaMin;

  final String observacoes;
  final List<String> fotoPaths;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Lancamento({
    this.id,
    required this.obraId,
    required this.dataHora,
    required this.caminhao,
    this.estruturaConcretada = '',
    this.concreteira = '',
    this.controleTecnologico = '',
    this.empresaTecnologiaConcreto = '',
    required this.volumeM3,
    this.dosagemKgM3 = 0.80,
    required this.cwsTotalKg,
    this.cwsAdicionadoKg,
    this.dosagemDeAcordo,
    this.notaFiscal = '',
    this.slumpAntes,
    this.slumpDepois,
    this.tempoMisturaMin,
    this.observacoes = '',
    this.fotoPaths = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  Lancamento copyWith({
    int? id,
    int? obraId,
    DateTime? dataHora,
    String? caminhao,
    String? estruturaConcretada,
    String? concreteira,
    String? controleTecnologico,
    String? empresaTecnologiaConcreto,
    double? volumeM3,
    double? dosagemKgM3,
    double? cwsTotalKg,
    double? cwsAdicionadoKg,
    int? dosagemDeAcordo,
    String? notaFiscal,
    double? slumpAntes,
    double? slumpDepois,
    double? tempoMisturaMin,
    String? observacoes,
    List<String>? fotoPaths,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Lancamento(
      id: id ?? this.id,
      obraId: obraId ?? this.obraId,
      dataHora: dataHora ?? this.dataHora,
      caminhao: caminhao ?? this.caminhao,
      estruturaConcretada: estruturaConcretada ?? this.estruturaConcretada,
      concreteira: concreteira ?? this.concreteira,
      controleTecnologico: controleTecnologico ?? this.controleTecnologico,
      empresaTecnologiaConcreto:
          empresaTecnologiaConcreto ?? this.empresaTecnologiaConcreto,
      volumeM3: volumeM3 ?? this.volumeM3,
      dosagemKgM3: dosagemKgM3 ?? this.dosagemKgM3,
      cwsTotalKg: cwsTotalKg ?? this.cwsTotalKg,
      cwsAdicionadoKg: cwsAdicionadoKg ?? this.cwsAdicionadoKg,
      dosagemDeAcordo: dosagemDeAcordo ?? this.dosagemDeAcordo,
      notaFiscal: notaFiscal ?? this.notaFiscal,
      slumpAntes: slumpAntes ?? this.slumpAntes,
      slumpDepois: slumpDepois ?? this.slumpDepois,
      tempoMisturaMin: tempoMisturaMin ?? this.tempoMisturaMin,
      observacoes: observacoes ?? this.observacoes,
      fotoPaths: fotoPaths ?? this.fotoPaths,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'obra_id': obraId,
      'data_hora': dataHora.toIso8601String(),
      'caminhao': caminhao,
      'estrutura_concretada': estruturaConcretada,
      'concreteira': concreteira,
      'controle_tecnologico': controleTecnologico,
      'empresa_tecnologia_concreto': empresaTecnologiaConcreto,
      'volume_m3': volumeM3,
      'dosagem_kg_m3': dosagemKgM3,
      'cws_total_kg': cwsTotalKg,
      'cws_adicionado_kg': cwsAdicionadoKg,
      'dosagem_de_acordo': dosagemDeAcordo,
      'nota_fiscal': notaFiscal,
      'slump_antes': slumpAntes,
      'slump_depois': slumpDepois,
      'tempo_mistura_min': tempoMisturaMin,
      'observacoes': observacoes,
      'foto_paths': jsonEncode(fotoPaths),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Lancamento.fromMap(Map<String, dynamic> map) {
    return Lancamento(
      id: map['id'] as int?,
      obraId: map['obra_id'] as int,
      dataHora: DateTime.parse(map['data_hora'] as String),
      caminhao: (map['caminhao'] ?? '') as String,
      estruturaConcretada: (map['estrutura_concretada'] ?? '') as String,
      concreteira: (map['concreteira'] ?? '') as String,
      controleTecnologico: (map['controle_tecnologico'] ?? '') as String,
      empresaTecnologiaConcreto:
          (map['empresa_tecnologia_concreto'] ?? '') as String,
      volumeM3: (map['volume_m3'] as num).toDouble(),
      dosagemKgM3: (map['dosagem_kg_m3'] as num).toDouble(),
      cwsTotalKg: (map['cws_total_kg'] as num).toDouble(),
      cwsAdicionadoKg: map['cws_adicionado_kg'] == null
          ? null
          : (map['cws_adicionado_kg'] as num).toDouble(),
      dosagemDeAcordo: map['dosagem_de_acordo'] as int?,
      notaFiscal: (map['nota_fiscal'] ?? '') as String,
      slumpAntes: map['slump_antes'] == null
          ? null
          : (map['slump_antes'] as num).toDouble(),
      slumpDepois: map['slump_depois'] == null
          ? null
          : (map['slump_depois'] as num).toDouble(),
      tempoMisturaMin: map['tempo_mistura_min'] == null
          ? null
          : (map['tempo_mistura_min'] as num).toDouble(),
      observacoes: (map['observacoes'] ?? '') as String,
      fotoPaths: _fotoPathsFromMap(map['foto_paths']),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  static List<String> _fotoPathsFromMap(dynamic raw) {
    if (raw == null) return const [];
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const [];
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded
              .whereType<String>()
              .map((path) => path.trim())
              .where((path) => path.isNotEmpty)
              .toList(growable: false);
        }
      } catch (_) {
        return const [];
      }
    }
    if (raw is List) {
      return raw
          .whereType<String>()
          .map((path) => path.trim())
          .where((path) => path.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }
}
