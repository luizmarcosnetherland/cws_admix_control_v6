class Lancamento {
  final int? id;
  final int obraId;
  final DateTime dataHora;

  /// Vamos usar como "Betoneira (nº/placa)" na UI, mantendo o nome antigo no banco.
  final String caminhao;

  final String concreteira;
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
  final DateTime createdAt;
  final DateTime updatedAt;

  const Lancamento({
    this.id,
    required this.obraId,
    required this.dataHora,
    required this.caminhao,
    this.concreteira = '',
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
    required this.createdAt,
    required this.updatedAt,
  });

  Lancamento copyWith({
    int? id,
    int? obraId,
    DateTime? dataHora,
    String? caminhao,
    String? concreteira,
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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Lancamento(
      id: id ?? this.id,
      obraId: obraId ?? this.obraId,
      dataHora: dataHora ?? this.dataHora,
      caminhao: caminhao ?? this.caminhao,
      concreteira: concreteira ?? this.concreteira,
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
      'concreteira': concreteira,
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
      concreteira: (map['concreteira'] ?? '') as String,
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
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
