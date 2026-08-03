import 'package:sqflite/sqflite.dart';

import '../../core/services/local_storage_service.dart';
import '../local/app_database.dart';
import '../models/concretagem_model.dart';

class ConcretagemRepository {
  final AppDatabase _db = AppDatabase.instance;
  final LocalStorageService _storage = LocalStorageService();

  Future<Concretagem> _recuperarPlantaLocal(
    Database db,
    Concretagem concretagem,
  ) async {
    final storedPath = concretagem.plantaPath.trim();
    if (storedPath.isEmpty) return concretagem;

    final resolvedPath = await _storage.resolveManagedFilePath(storedPath);
    if (resolvedPath == null || resolvedPath == storedPath) return concretagem;

    if (concretagem.id != null) {
      await db.update(
        'concretagens',
        {'planta_path': resolvedPath},
        where: 'id = ?',
        whereArgs: [concretagem.id],
      );
    }
    return concretagem.copyWith(plantaPath: resolvedPath);
  }

  Future<List<Concretagem>> listarPorObra(int obraId) async {
    final db = await _db.database;
    final rows = await db.query(
      'concretagens',
      where: 'obra_id = ?',
      whereArgs: [obraId],
      orderBy: 'created_at DESC',
    );
    final concretagens = <Concretagem>[];
    for (final row in rows) {
      final concretagem = Concretagem.fromMap(Map<String, dynamic>.from(row));
      concretagens.add(await _recuperarPlantaLocal(db, concretagem));
    }
    return concretagens;
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
    final concretagem = Concretagem.fromMap(
      Map<String, dynamic>.from(rows.first),
    );
    return _recuperarPlantaLocal(db, concretagem);
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
