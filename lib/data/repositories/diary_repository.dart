import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/diary_entry.dart';
import '../models/entry_digest.dart';

class DiaryRepository {
  DiaryRepository({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

  Future<Database> get _d => _db.database;

  /// 全部日记，新的在前
  Future<List<DiaryEntry>> listAll({int? limit}) async {
    final db = await _d;
    final rows = await db.query(
      'entries',
      orderBy: 'date_key DESC',
      limit: limit,
    );
    return rows.map(DiaryEntry.fromMap).toList();
  }

  Future<DiaryEntry?> byDateKey(String dateKey) async {
    final db = await _d;
    final rows = await db.query(
      'entries',
      where: 'date_key = ?',
      whereArgs: [dateKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DiaryEntry.fromMap(rows.first);
  }

  Future<void> upsert(DiaryEntry entry) async {
    final db = await _d;
    await db.insert(
      'entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final db = await _d;
    await db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> count() async {
    final db = await _d;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM entries');
    return (rows.first['c'] as int?) ?? 0;
  }

  /// 尚未纳入画像的日记，按时间正序（先读旧的，画像才长得自然）
  Future<List<DiaryEntry>> pendingAnalysis() async {
    final db = await _d;
    final rows = await db.query(
      'entries',
      where: 'analyzed = 0',
      orderBy: 'date_key ASC',
    );
    return rows.map(DiaryEntry.fromMap).toList();
  }

  Future<void> markAnalyzed(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    final db = await _d;
    final batch = db.batch();
    for (final id in ids) {
      batch.update('entries', {'analyzed': 1},
          where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  /// 跳过画像（比如只是记了一行待办）
  Future<void> markSkipped(Iterable<String> ids) => markAnalyzed(ids);

  // --- 单篇分析缓存 ---------------------------------------------------------

  Future<void> saveDigest(EntryDigest digest) async {
    final db = await _d;
    await db.insert(
      'digests',
      {
        'date_key': digest.dateKey,
        'payload': jsonEncode(digest.toJson()),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<EntryDigest?> digestFor(String dateKey) async {
    final db = await _d;
    final rows = await db.query('digests',
        where: 'date_key = ?', whereArgs: [dateKey], limit: 1);
    if (rows.isEmpty) return null;
    try {
      final decoded = jsonDecode(rows.first['payload'] as String);
      if (decoded is Map) {
        return EntryDigest.fromJson(
            decoded.map((k, v) => MapEntry(k.toString(), v)));
      }
    } catch (_) {
      // 损坏则当作没有缓存
    }
    return null;
  }

  /// 最近的 digests，用于给画像合并和对话提供近期上下文
  Future<List<EntryDigest>> recentDigests({int limit = 30}) async {
    final db = await _d;
    final rows = await db.query(
      'digests',
      orderBy: 'date_key DESC',
      limit: limit,
    );
    final out = <EntryDigest>[];
    for (final r in rows) {
      try {
        final decoded = jsonDecode(r['payload'] as String);
        if (decoded is Map) {
          out.add(EntryDigest.fromJson(
              decoded.map((k, v) => MapEntry(k.toString(), v))));
        }
      } catch (_) {
        // 跳过
      }
    }
    return out;
  }

  /// 最近 N 天日记原文，给「知己」做上下文
  Future<List<DiaryEntry>> recentEntries({int days = 14}) async {
    final db = await _d;
    final rows = await db.query(
      'entries',
      orderBy: 'date_key DESC',
      limit: days,
    );
    return rows.map(DiaryEntry.fromMap).toList();
  }
}
