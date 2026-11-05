import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/insight.dart';
import '../models/persona.dart';

class PersonaRepository {
  PersonaRepository({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

  Future<Database> get _d => _db.database;

  /// 当前画像 = 最新快照
  Future<Persona> latest() async {
    final db = await _d;
    final rows = await db.query('persona_snapshots',
        orderBy: 'id DESC', limit: 1);
    if (rows.isEmpty) return Persona.empty();
    return Persona.fromJsonString(rows.first['payload'] as String?);
  }

  /// 写入新快照，返回落库后的画像
  Future<Persona> save(Persona persona) async {
    final db = await _d;
    await db.insert('persona_snapshots', {
      'version': persona.version,
      'created_at': persona.updatedAt.millisecondsSinceEpoch,
      'entries_covered': persona.entriesCovered,
      'payload': persona.toJsonString(),
    });
    return persona;
  }

  /// 历史快照（含当前），用于「三个月前的我」
  Future<List<Persona>> history({int limit = 20}) async {
    final db = await _d;
    final rows = await db.query('persona_snapshots',
        orderBy: 'id DESC', limit: limit);
    return rows
        .map((r) => Persona.fromJsonString(r['payload'] as String?))
        .toList();
  }

  Future<void> addInsights(Iterable<Insight> insights) async {
    if (insights.isEmpty) return;
    final db = await _d;
    final batch = db.batch();
    for (final i in insights) {
      batch.insert('insights', i.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Insight>> insights({int limit = 100}) async {
    final db = await _d;
    final rows = await db.query('insights',
        orderBy: 'created_at DESC', limit: limit);
    return rows.map(Insight.fromMap).toList();
  }

  Future<Map<String, Object?>?> _first(String sql, List<Object?> args) async {
    final db = await _d;
    final rows = await db.rawQuery(sql, args);
    return rows.isEmpty ? null : rows.first;
  }

  /// 统计概览：写了多少天、覆盖了多长时间
  Future<PersonaStats> stats() async {
    final total = await _first('SELECT COUNT(*) AS c FROM entries', []);
    final span = await _first(
        'SELECT MIN(date_key) AS first, MAX(date_key) AS last FROM entries', []);
    return PersonaStats(
      entryCount: (total?['c'] as int?) ?? 0,
      firstDateKey: span?['first'] as String?,
      lastDateKey: span?['last'] as String?,
    );
  }

  /// 导出用：一次性读出全部洞察
  Future<List<Insight>> allInsightsAsc() async {
    final db = await _d;
    final rows = await db.query('insights', orderBy: 'date_key ASC');
    return rows.map(Insight.fromMap).toList();
  }

  /// 调试/备份：整表 JSON
  Future<String> dumpSnapshots() async {
    final db = await _d;
    final rows = await db.query('persona_snapshots', orderBy: 'id ASC');
    return jsonEncode(rows);
  }
}

class PersonaStats {
  const PersonaStats({
    required this.entryCount,
    this.firstDateKey,
    this.lastDateKey,
  });

  final int entryCount;
  final String? firstDateKey;
  final String? lastDateKey;

  int get spanDays {
    if (firstDateKey == null || lastDateKey == null) return 0;
    final a = DateTime.tryParse(firstDateKey!);
    final b = DateTime.tryParse(lastDateKey!);
    if (a == null || b == null) return 0;
    return b.difference(a).inDays + 1;
  }
}
