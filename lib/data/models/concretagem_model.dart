class Concretagem {
  final int? id;
  final int obraId;
  final String estruturaConcretada;
  final String concreteira;
  final String controleTecnologico;
  final String empresaTecnologiaConcreto;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Concretagem({
    this.id,
    required this.obraId,
    this.estruturaConcretada = '',
    this.concreteira = '',
    this.controleTecnologico = '',
    this.empresaTecnologiaConcreto = '',
    required this.createdAt,
    required this.updatedAt,
  });

  Concretagem copyWith({
    int? id,
    int? obraId,
    String? estruturaConcretada,
    String? concreteira,
    String? controleTecnologico,
    String? empresaTecnologiaConcreto,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Concretagem(
      id: id ?? this.id,
      obraId: obraId ?? this.obraId,
      estruturaConcretada: estruturaConcretada ?? this.estruturaConcretada,
      concreteira: concreteira ?? this.concreteira,
      controleTecnologico: controleTecnologico ?? this.controleTecnologico,
      empresaTecnologiaConcreto:
          empresaTecnologiaConcreto ?? this.empresaTecnologiaConcreto,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'obra_id': obraId,
      'estrutura_concretada': estruturaConcretada,
      'concreteira': concreteira,
      'controle_tecnologico': controleTecnologico,
      'empresa_tecnologia_concreto': empresaTecnologiaConcreto,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Concretagem.fromMap(Map<String, dynamic> map) {
    return Concretagem(
      id: map['id'] as int?,
      obraId: map['obra_id'] as int,
      estruturaConcretada: (map['estrutura_concretada'] ?? '') as String,
      concreteira: (map['concreteira'] ?? '') as String,
      controleTecnologico: (map['controle_tecnologico'] ?? '') as String,
      empresaTecnologiaConcreto:
          (map['empresa_tecnologia_concreto'] ?? '') as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
