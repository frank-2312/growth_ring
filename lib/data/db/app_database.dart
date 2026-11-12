import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 本地唯一的真相来源。全部数据留在设备上，
/// 只有在你主动让它「读一读」或提问时，相关文本才会离开这台机器。
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'growth_ring.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE entries (
            id TEXT PRIMARY KEY,
            date_key TEXT NOT NULL UNIQUE,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            content TEXT NOT NULL,
            title TEXT,
            mood TEXT,
            energy INTEGER,
            tags TEXT,
            photos TEXT,
            echo TEXT,
            analyzed INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_entries_date ON entries(date_key DESC)');

        // 单篇结构化读取结果，按日期缓存，重算画像时不必重新读原文
        await db.execute('''
          CREATE TABLE digests (
            date_key TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE persona_snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            version INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            entries_covered INTEGER NOT NULL,
            payload TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE insights (
            id TEXT PRIMARY KEY,
            created_at INTEGER NOT NULL,
            date_key TEXT NOT NULL,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            quote TEXT
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_insights_created ON insights(created_at DESC)');

        await db.execute('''
          CREATE TABLE chat_messages (
            id TEXT PRIMARY KEY,
            from_user INTEGER NOT NULL,
            text TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
      },
      // v1 → v2：日记开始支持配图。老行迁移后是 NULL，
      // 读的时候当空列表处理，不做回填（免得动到用户已有数据）。
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE entries ADD COLUMN photos TEXT');
        }
      },
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// 危险操作，仅用于「清空所有数据」
  Future<void> wipe() async {
    final db = await database;
    for (final table in [
      'entries',
      'digests',
      'persona_snapshots',
      'insights',
      'chat_messages',
    ]) {
      await db.delete(table);
    }
  }
}
