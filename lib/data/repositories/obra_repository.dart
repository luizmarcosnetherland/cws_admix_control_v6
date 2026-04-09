import 'package:sqflite/sqflite.dart';

import '../local/app_database.dart';
import '../models/obra_model.dart';

class ObraRepository {
  final AppDatabase _db = AppDatabase.instance;

  Future<List<Obra>> listarObrasAtivas() async {
    final db = await _db.database;

    final rows = await db.query(
      'obras',
      where: 'ativo = ?',
      whereArgs: [1],
      orderBy: 'created_at DESC',
    );

    return rows.map((e) => Obra.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<Obra>> listarObrasArquivadas() async {
    final db = await _db.database;

    final rows = await db.query(
      'obras',
      where: 'ativo = ?',
      whereArgs: [0],
      orderBy: 'updated_at DESC',
    );

    return rows.map((e) => Obra.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<bool> nomeJaExiste(String nome) async {
    final db = await _db.database;

    final rows = await db.query(
      'obras',
      columns: ['id'],
      where: 'LOWER(nome) = ? AND ativo = 1',
      whereArgs: [nome.trim().toLowerCase()],
      limit: 1,
    );

    return rows.isNotEmpty;
  }

  Future<int> criarObra({
    required String nome,
    String cliente = '',
    String local = '',
    String responsavel = '',
    String emailEngenheiro = '',
    double? latitude,
    double? longitude,
    String localizacaoDescricao = '',
    String observacoes = '',
  }) async {
    final db = await _db.database;
    final now = DateTime.now();

    final obra = Obra(
      nome: nome.trim(),
      cliente: cliente.trim(),
      local: local.trim(),
      responsavel: responsavel.trim(),
      emailEngenheiro: emailEngenheiro.trim(),
      latitude: latitude,
      longitude: longitude,
      localizacaoDescricao: localizacaoDescricao.trim(),
      observacoes: observacoes.trim(),
      createdAt: now,
      updatedAt: now,
    );

    return db.insert(
      'obras',
      obra.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> atualizarObra(Obra obra) async {
    final db = await _db.database;
    final updated = obra.copyWith(updatedAt: DateTime.now());

    return db.update(
      'obras',
      updated.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [obra.id],
    );
  }

  Future<int> arquivarObra(int id) async {
    final db = await _db.database;

    return db.update(
      'obras',
      {'ativo': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> restaurarObra(int id) async {
    final db = await _db.database;

    return db.update(
      'obras',
      {'ativo': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> excluirObra(int id) async {
    final db = await _db.database;

    await db.transaction((txn) async {
      await txn.delete('lancamentos', where: 'obra_id = ?', whereArgs: [id]);
      await txn.delete('concretagens', where: 'obra_id = ?', whereArgs: [id]);
      await txn.delete('obras', where: 'id = ?', whereArgs: [id]);
    });
  }
}
