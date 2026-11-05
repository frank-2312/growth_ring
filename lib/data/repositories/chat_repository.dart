import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/chat_message.dart';

class ChatRepository {
  ChatRepository({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

  Future<Database> get _d => _db.database;

  Future<List<ChatMessage>> list({int limit = 200}) async {
    final db = await _d;
    final rows = await db.query(
      'chat_messages',
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(ChatMessage.fromMap).toList();
  }

  Future<void> append(ChatMessage message) async {
    final db = await _d;
    await db.insert('chat_messages', message.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clear() async {
    final db = await _d;
    await db.delete('chat_messages');
  }
}
