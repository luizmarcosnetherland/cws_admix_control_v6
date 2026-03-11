import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'cws_admix_control.db';
  static const _dbVersion = 9;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      await _ensureSchema(_database!);
      return _database!;
    }
    _database = await _open();
    await _ensureSchema(_database!);
    return _database!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);

    return openDatabase(
      fullPath,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await _ensureLancamentosColumns(db);
        await _ensureObrasColumns(db);
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createObrasTable(db);
    await _createLancamentosTable(db);
  }

  Future<void> _ensureSchema(Database db) async {
    await _ensureLancamentosColumns(db);
    await _ensureObrasColumns(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 -> v2: cria tabela de lançamentos
    if (oldVersion < 2) {
      await _createLancamentosTable(db);    await _ensureLancamentosColumns(db);

    }

 // v2 -> v3: adiciona campos extras de lançamento
if (oldVersion < 3) {
  // NOT NULL precisa de DEFAULT
  await db.execute(
    "ALTER TABLE lancamentos ADD COLUMN nota_fiscal TEXT NOT NULL DEFAULT ''",
  );

  // campos numéricos opcionais (podem ser NULL)
  await db.execute("ALTER TABLE lancamentos ADD COLUMN slump_antes REAL");
  await db.execute("ALTER TABLE lancamentos ADD COLUMN slump_depois REAL");
  await db.execute(
    "ALTER TABLE lancamentos ADD COLUMN tempo_mistura_min REAL",
  );
}

// v3 -> v4: controle de CWS adicionado + validação
if (oldVersion < 4) {
  final cols = await db.rawQuery("PRAGMA table_info(lancamentos)");
  final names = cols.map((e) => e['name'] as String).toSet();

  if (!names.contains('cws_adicionado_kg')) {
    await db.execute(
      "ALTER TABLE lancamentos ADD COLUMN cws_adicionado_kg REAL",
    );
    if (oldVersion < 7) {
      final cols = await db.rawQuery("PRAGMA table_info(lancamentos)");
      final names = cols.map((e) => e['name'] as String).toSet();

      if (!names.contains('cws_adicionado_kg')) {
        await db.execute("ALTER TABLE lancamentos ADD COLUMN cws_adicionado_kg REAL");
      }
      if (!names.contains('dosagem_de_acordo')) {
        await db.execute("ALTER TABLE lancamentos ADD COLUMN dosagem_de_acordo INTEGER");
      }
    }


  }

    if (oldVersion < 5) {
      final cols = await db.rawQuery("PRAGMA table_info(lancamentos)");
      final names = cols.map((e) => e['name'] as String).toSet();

      if (!names.contains('cws_adicionado_kg')) {
        await db.execute("ALTER TABLE lancamentos ADD COLUMN cws_adicionado_kg REAL");
      }
      if (!names.contains('dosagem_de_acordo')) {
        await db.execute("ALTER TABLE lancamentos ADD COLUMN dosagem_de_acordo INTEGER");
      }
    }

  if (!names.contains('dosagem_de_acordo')) {
    await db.execute(
      "ALTER TABLE lancamentos ADD COLUMN dosagem_de_acordo INTEGER",
    );
  }
}
  }

  Future<void> _createObrasTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS obras (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        cliente TEXT NOT NULL DEFAULT '',
        local TEXT NOT NULL DEFAULT '',
        responsavel TEXT NOT NULL DEFAULT '',
        email_engenheiro TEXT NOT NULL DEFAULT '',
        observacoes TEXT NOT NULL DEFAULT '',
        ativo INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_obras_ativo_created_at ON obras (ativo, created_at DESC)',
    );
  }

  Future<void> _createLancamentosTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lancamentos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        obra_id INTEGER NOT NULL,
        data_hora TEXT NOT NULL,
        caminhao TEXT NOT NULL,
        concreteira TEXT NOT NULL DEFAULT '',
        volume_m3 REAL NOT NULL,
        dosagem_kg_m3 REAL NOT NULL DEFAULT 0.80,
        cws_total_kg REAL NOT NULL,
        nota_fiscal TEXT NOT NULL DEFAULT '',
        slump_antes REAL,
        slump_depois REAL,
        tempo_mistura_min REAL,
        observacoes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (obra_id) REFERENCES obras(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_lancamentos_obra_data ON lancamentos (obra_id, data_hora DESC)',
    );
  }

  Future<void> _ensureLancamentosColumns(Database db) async {
    final cols = await db.rawQuery("PRAGMA table_info(lancamentos)");
    final names = cols.map((e) => e['name'] as String).toSet();

    if (!names.contains('cws_adicionado_kg')) {
      await db.execute("ALTER TABLE lancamentos ADD COLUMN cws_adicionado_kg REAL");
    }
    if (!names.contains('dosagem_de_acordo')) {
      await db.execute("ALTER TABLE lancamentos ADD COLUMN dosagem_de_acordo INTEGER");
    }
  }

  Future<void> _ensureObrasColumns(Database db) async {
    final cols = await db.rawQuery("PRAGMA table_info(obras)");
    final names = cols.map((e) => e['name'] as String).toSet();

    if (!names.contains('email_engenheiro')) {
      await db.execute(
        "ALTER TABLE obras ADD COLUMN email_engenheiro TEXT NOT NULL DEFAULT ''",
      );
    }
  }

}
