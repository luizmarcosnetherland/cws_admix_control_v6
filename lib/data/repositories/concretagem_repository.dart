import 'package:sqflite/sqflite.dart';

import '../local/app_database.dart';
import '../models/concretagem_model.dart';

class ConcretagemRepository {
  final AppDatabase _db = AppDatabase.instance;

  Future<List<Concretagem>> listarPorObra(int obraId) async {
    final db = await _db.database;
    final rows = await db.query(
      'concretagens',
      where: 'obra_id = ?',
      whereArgs: [obraId],
      orderBy: 'created_at DESC',
    );
    return rows
        .map((row) => Concretagem.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<Concretagem?> buscarPorId(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      'concretagens',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Concretagem.fromMap(Map<String, dynamic>.from(rows.first));
  }

  Future<Concretagem> criarConcretagem({
    required int obraId,
    String estruturaConcretada = '',
    String concreteira = '',
    String controleTecnologico = '',
    String empresaTecnologiaConcreto = '',
  }) async {
    final db = await _db.database;
    final now = DateTime.now();
    final concretagem = Concretagem(
      obraId: obraId,
      estruturaConcretada: estruturaConcretada.trim(),
      concreteira: concreteira.trim(),
      controleTecnologico: controleTecnologico.trim(),
      empresaTecnologiaConcreto: empresaTecnologiaConcreto.trim(),
      createdAt: now,
      updatedAt: now,
    );

    final id = await db.insert(
      'concretagens',
      concretagem.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return concretagem.copyWith(id: id);
  }

  Future<Concretagem> atualizarConcretagem(Concretagem concretagem) async {
    final db = await _db.database;
    final updated = concretagem.copyWith(updatedAt: DateTime.now());
    await db.update(
      'concretagens',
      updated.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [concretagem.id],
    );
    return updated;
  }

  Future<void> excluirConcretagem(int id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete(
        'lancamentos',
        where: 'concretagem_id = ?',
        whereArgs: [id],
      );
      await txn.delete('concretagens', where: 'id = ?', whereArgs: [id]);
    });
  }
}
