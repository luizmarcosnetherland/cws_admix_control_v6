import 'dart:convert';

class ConcretagemRastreioPonto {
  final double x;
  final double y;

  const ConcretagemRastreioPonto({required this.x, required this.y});

  Map<String, dynamic> toMap() {
    return {'x': x, 'y': y};
  }

  factory ConcretagemRastreioPonto.fromMap(Map<String, dynamic> map) {
    final x = _asDouble(map['x']);
    final y = _asDouble(map['y']);
    return ConcretagemRastreioPonto(x: x ?? 0, y: y ?? 0);
  }

  static double? _asDouble(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }
}

class ConcretagemRastreioTraco {
  final int lancamentoId;
  final double brushSize;
  final double brushScale;
  final List<ConcretagemRastreioPonto> points;

  const ConcretagemRastreioTraco({
    required this.lancamentoId,
    required this.brushSize,
    this.brushScale = 0,
    required this.points,
  });

  Map<String, dynamic> toMap() {
    return {
      'lancamento_id': lancamentoId,
      'brush_size': brushSize,
      'brush_scale': brushScale,
      'points': points.map((item) => item.toMap()).toList(growable: false),
    };
  }

  factory ConcretagemRastreioTraco.fromMap(Map<String, dynamic> map) {
    final rawPoints = map['points'];
    final parsedPoints = <ConcretagemRastreioPonto>[];
    if (rawPoints is List) {
      for (final item in rawPoints) {
        if (item is Map<String, dynamic>) {
          parsedPoints.add(ConcretagemRastreioPonto.fromMap(item));
        } else if (item is Map) {
          parsedPoints.add(
            ConcretagemRastreioPonto.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return ConcretagemRastreioTraco(
      lancamentoId: map['lancamento_id'] as int? ?? 0,
      brushSize: ConcretagemRastreioPonto._asDouble(map['brush_size']) ?? 18,
      brushScale: ConcretagemRastreioPonto._asDouble(map['brush_scale']) ?? 0,
      points: parsedPoints,
    );
  }

  double resolveBrushSize(double minSide, {double legacyBase = 320}) {
    if (brushScale > 0 && minSide > 0) {
      return brushScale * minSide;
    }
    if (brushSize <= 0) return 0;
    if (minSide <= 0) return brushSize;
    return brushSize * (minSide / legacyBase);
  }
}

class Concretagem {
  final int? id;
  final int obraId;
  final String estruturaConcretada;
  final String concreteira;
  final String controleTecnologico;
  final String empresaTecnologiaConcreto;
  final String plantaPath;
  final List<ConcretagemRastreioTraco> rastreioTracos;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Concretagem({
    this.id,
    required this.obraId,
    this.estruturaConcretada = '',
    this.concreteira = '',
    this.controleTecnologico = '',
    this.empresaTecnologiaConcreto = '',
    this.plantaPath = '',
    this.rastreioTracos = const [],
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
    String? plantaPath,
    List<ConcretagemRastreioTraco>? rastreioTracos,
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
      plantaPath: plantaPath ?? this.plantaPath,
      rastreioTracos: rastreioTracos ?? this.rastreioTracos,
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
      'planta_path': plantaPath,
      'rastreio_tracos': jsonEncode(
        rastreioTracos.map((item) => item.toMap()).toList(growable: false),
      ),
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
      plantaPath: (map['planta_path'] ?? '') as String,
      rastreioTracos: _rastreioTracosFromRaw(map['rastreio_tracos']),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  static List<ConcretagemRastreioTraco> _rastreioTracosFromRaw(dynamic raw) {
    if (raw == null) return const [];

    dynamic decoded = raw;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const [];
      try {
        decoded = jsonDecode(trimmed);
      } catch (_) {
        return const [];
      }
    }

    if (decoded is! List) return const [];

    return decoded
        .whereType<Object?>()
        .map((item) {
          if (item is Map<String, dynamic>) {
            return ConcretagemRastreioTraco.fromMap(item);
          }
          if (item is Map) {
            return ConcretagemRastreioTraco.fromMap(
              Map<String, dynamic>.from(item),
            );
          }
          return null;
        })
        .whereType<ConcretagemRastreioTraco>()
        .where(
          (item) =>
              item.lancamentoId > 0 &&
              item.brushSize > 0 &&
              item.points.length >= 2,
        )
        .toList(growable: false);
  }
}
