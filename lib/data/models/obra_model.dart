class Obra {
  final int? id;
  final String nome;
  final String cliente;
  final String local;
  final String responsavel;
  final String? _emailEngenheiro;
  final double? latitude;
  final double? longitude;
  final String localizacaoDescricao;
  final String observacoes;
  final bool ativo;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get emailEngenheiro => _emailEngenheiro ?? '';

  const Obra({
    this.id,
    required this.nome,
    this.cliente = '',
    this.local = '',
    this.responsavel = '',
    String? emailEngenheiro = '',
    this.latitude,
    this.longitude,
    this.localizacaoDescricao = '',
    this.observacoes = '',
    this.ativo = true,
    required this.createdAt,
    required this.updatedAt,
  }) : _emailEngenheiro = emailEngenheiro;

  Obra copyWith({
    int? id,
    String? nome,
    String? cliente,
    String? local,
    String? responsavel,
    String? emailEngenheiro,
    double? latitude,
    double? longitude,
    String? localizacaoDescricao,
    String? observacoes,
    bool? ativo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Obra(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      cliente: cliente ?? this.cliente,
      local: local ?? this.local,
      responsavel: responsavel ?? this.responsavel,
      emailEngenheiro: emailEngenheiro ?? this.emailEngenheiro,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      localizacaoDescricao: localizacaoDescricao ?? this.localizacaoDescricao,
      observacoes: observacoes ?? this.observacoes,
      ativo: ativo ?? this.ativo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'cliente': cliente,
      'local': local,
      'responsavel': responsavel,
      'email_engenheiro': emailEngenheiro,
      'latitude': latitude,
      'longitude': longitude,
      'localizacao_descricao': localizacaoDescricao,
      'observacoes': observacoes,
      'ativo': ativo ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Obra.fromMap(Map<String, dynamic> map) {
    return Obra(
      id: map['id'] as int?,
      nome: (map['nome'] as String?) ?? '',
      cliente: (map['cliente'] as String?) ?? '',
      local: (map['local'] as String?) ?? '',
      responsavel: (map['responsavel'] as String?) ?? '',
      emailEngenheiro: (map['email_engenheiro'] as String?) ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      localizacaoDescricao: (map['localizacao_descricao'] as String?) ?? '',
      observacoes: (map['observacoes'] as String?) ?? '',
      ativo: (map['ativo'] ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
