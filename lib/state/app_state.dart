import 'dart:async';

import 'package:flutter/material.dart';

import '../core/fmt.dart';
import '../data/db/app_database.dart';
import '../data/models/chat_message.dart';
import '../data/models/diary_entry.dart';
import '../data/models/insight.dart';
import '../data/models/persona.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/diary_repository.dart';
import '../data/repositories/persona_repository.dart';
import '../data/settings/settings_store.dart';
import '../llm/llm_client.dart';
import '../llm/persona_engine.dart';
import '../llm/prompts.dart';

/// 全局状态。用 ChangeNotifier 而不是更重的方案：
/// 这个应用的数据关系很简单，一个宿主对象足够，读起来也更直接。
class AppState extends ChangeNotifier {
  AppState({
    required this.settingsStore,
    DiaryRepository? diary,
    PersonaRepository? personas,
    ChatRepository? chats,
  })  : diary = diary ?? DiaryRepository(),
        personas = personas ?? PersonaRepository(),
        chats = chats ?? ChatRepository();

  final SettingsStore settingsStore;
  final DiaryRepository diary;
  final PersonaRepository personas;
  final ChatRepository chats;

  AppSettings settings = const AppSettings();
  List<DiaryEntry> entries = const [];
  Persona persona = Persona.empty();
  List<Insight> insights = const [];
  List<ChatMessage> chatMessages = const [];
  PersonaStats stats =
      const PersonaStats(entryCount: 0, firstDateKey: null, lastDateKey: null);

  bool booted = false;
  bool reflecting = false;
  bool chatting = false;
  String reflectStage = '';
  String? lastError;

  /// 启动阶段就失败（数据库打不开等）。此时必须让用户看见原因，
  /// 而不是永远停在一个只有「年轮」两个字的开屏页。
  String? bootError;
  int pendingCount = 0;

  bool _disposed = false;

  // --- 生命周期 -----------------------------------------------------------

  Future<void> init() async {
    bootError = null;
    _notify();
    try {
      settings = await settingsStore.load();
      await refreshAll();
    } catch (e) {
      bootError = e.toString();
    }
    booted = true;
    _notify();
  }

  Future<void> refreshAll() async {
    entries = await diary.listAll();
    persona = await personas.latest();
    insights = await personas.insights(limit: 80);
    chatMessages = await chats.list();
    stats = await personas.stats();
    pendingCount = (await diary.pendingAnalysis()).length;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // --- 派生 ---------------------------------------------------------------

  bool get isConfigured => settings.llm.isConfigured;

  String get displayName =>
      settings.nickname.trim().isEmpty ? '你' : settings.nickname.trim();

  DiaryEntry? entryForDate(String dateKey) {
    for (final e in entries) {
      if (e.dateKey == dateKey) return e;
    }
    return null;
  }

  DiaryEntry? get todayEntry => entryForDate(Fmt.dateKey(DateTime.now()));

  int get writtenDays => entries.where((e) => !e.isEmpty).length;

  /// 连续写了多少天（今天没写则从昨天算起，不算断签，只是提醒）
  int get streak {
    if (entries.isEmpty) return 0;
    final byDate = {
      for (final e in entries)
        if (!e.isEmpty) e.dateKey: e
    };
    if (byDate.isEmpty) return 0;
    var cursor = DateTime.now();
    if (!byDate.containsKey(Fmt.dateKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var count = 0;
    while (byDate.containsKey(Fmt.dateKey(cursor))) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  LlmClient _client() => LlmClient(settings.llm);

  // --- 日记 ---------------------------------------------------------------

  /// 保存（或新建）某一天的日记，返回落库后的实体
  Future<DiaryEntry> saveEntry({
    required String dateKey,
    required String content,
    String? mood,
    int? energy,
    List<String> tags = const [],
  }) async {
    final existing = entryForDate(dateKey);
    final now = DateTime.now();
    final title = Fmt.deriveTitle(content);

    final entry = (existing ??
            DiaryEntry(
              id: newId('e'),
              dateKey: dateKey,
              createdAt: now,
              updatedAt: now,
              content: '',
            ))
        .copyWith(
      content: content,
      title: title,
      mood: mood,
      energy: energy,
      tags: tags,
      updatedAt: now,
      // 内容变了就要重新读一遍，画像才能跟上
      analyzed: existing?.content == content ? (existing?.analyzed ?? false) : false,
    );

    await diary.upsert(entry);
    await refreshAll();
    return entry;
  }

  Future<void> deleteEntry(String id) async {
    await diary.delete(id);
    await refreshAll();
  }

  /// 写完之后让模型留一句话。失败静默，不打断记录本身。
  Future<void> requestEcho(DiaryEntry entry) async {
    if (!isConfigured || entry.content.trim().isEmpty) return;
    final client = _client();
    try {
      final engine = PersonaEngine(client: client, diary: diary, personas: personas);
      final text = await engine.echo(
        entry: entry,
        persona: persona,
        nickname: settings.nickname,
      );
      if (text == null) return;
      final updated = entry.copyWith(echo: text);
      await diary.upsert(updated);
      await refreshAll();
    } catch (_) {
      // 忽略
    } finally {
      client.dispose();
    }
  }

  /// 把手写回填到所有历史条目
  Future<void> replaceInAllEntries(String from, String to) async {
    for (final e in entries) {
      if (e.content.contains(from)) {
        await diary.upsert(e.copyWith(content: e.content.replaceAll(from, to)));
      }
    }
    await refreshAll();
  }

  // --- 画像 ---------------------------------------------------------------

  /// 让模型读一批新日记并更新画像。返回本次变化说明，出错返回 null 并把信息放进 lastError。
  Future<ReflectResult?> reflectNow() async {
    if (reflecting) return null;
    if (!isConfigured) {
      lastError = '还没配置模型。去「设置」里填好接口和密钥，它才能开始读。';
      _notify();
      return null;
    }

    reflecting = true;
    reflectStage = '准备中';
    lastError = null;
    _notify();

    final client = _client();
    try {
      final engine = PersonaEngine(client: client, diary: diary, personas: personas);
      final result = await engine.reflect(
        current: persona,
        nickname: settings.nickname,
        onProgress: (stage, done, total) {
          reflectStage = total > 0 ? '$stage（$done/$total）' : stage;
          _notify();
        },
      );
      reflecting = false;
      reflectStage = '';
      await refreshAll();
      return result;
    } catch (e) {
      lastError = e.toString();
      reflecting = false;
      reflectStage = '';
      _notify();
      return null;
    } finally {
      client.dispose();
    }
  }

  Future<String> generateRetrospective({int days = 30}) async {
    if (!isConfigured) {
      throw Exception('还没配置模型');
    }
    final client = _client();
    try {
      final engine = PersonaEngine(client: client, diary: diary, personas: personas);
      return await engine.retrospective(
        persona: persona,
        nickname: settings.nickname,
        days: days,
      );
    } finally {
      client.dispose();
    }
  }

  // --- 对话 ---------------------------------------------------------------

  Future<void> sendMessage(String text) async {
    final content = text.trim();
    if (content.isEmpty || chatting) return;
    if (!isConfigured) {
      lastError = '还没配置模型，暂时聊不了。';
      _notify();
      return;
    }

    final userMsg = ChatMessage(
      id: newId('c'),
      fromUser: true,
      text: content,
      createdAt: DateTime.now(),
    );
    final placeholder = ChatMessage(
      id: newId('c'),
      fromUser: false,
      text: '',
      createdAt: DateTime.now(),
      streaming: true,
    );

    chatMessages = [...chatMessages, userMsg, placeholder];
    chatting = true;
    _notify();

    await chats.append(userMsg);

    final client = _client();
    try {
      // 记忆材料给得太多，模型就会忍不住逐条引用。宁可少给一点。
      final recentDigests = await diary.recentDigests(limit: 10);
      final recentEntries = await diary.recentEntries(days: 3);
      final system = Prompts.companion(
        persona: persona,
        nickname: settings.nickname,
        style: settings.companion,
        recentDigests: recentDigests,
        recentEntries: recentEntries,
      );

      // 只带最近 12 轮，避免上下文无限膨胀
      final history = chatMessages
          .where((m) => !m.streaming && m.id != placeholder.id)
          .toList();
      final window = history.length > 12
          ? history.sublist(history.length - 12)
          : history;

      final messages = <Map<String, String>>[
        ...system,
        ...window.map((m) => m.toApiJson()),
      ];

      final buffer = StringBuffer();
      await for (final chunk in client.stream(messages, temperature: 0.8)) {
        buffer.write(chunk);
        _replaceLastAssistant(buffer.toString(), streaming: true);
      }

      final finalText = buffer.toString().trim();
      if (finalText.isEmpty) {
        _replaceLastAssistant('（它这次没说出话来，再问一次试试）', streaming: false);
      } else {
        _replaceLastAssistant(finalText, streaming: false);
        await chats.append(ChatMessage(
          id: placeholder.id,
          fromUser: false,
          text: finalText,
          createdAt: placeholder.createdAt,
        ));
      }
    } catch (e) {
      _replaceLastAssistant(e.toString(), streaming: false);
    } finally {
      client.dispose();
      chatting = false;
      _notify();
    }
  }

  void _replaceLastAssistant(String text, {required bool streaming}) {
    if (chatMessages.isEmpty) return;
    final updated = [...chatMessages];
    updated[updated.length - 1] =
        updated.last.copyWith(text: text, streaming: streaming);
    chatMessages = updated;
    _notify();
  }

  Future<void> clearChat() async {
    await chats.clear();
    chatMessages = const [];
    _notify();
  }

  // --- 设置 ---------------------------------------------------------------

  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    await settingsStore.save(next);
    _notify();
  }

  Future<String> testConnection() async {
    final client = _client();
    try {
      return await client.testConnection();
    } finally {
      client.dispose();
    }
  }

  // --- 危险操作 -----------------------------------------------------------

  Future<void> wipeEverything() async {
    // 清空必须彻底：日记没了但画像还在，会让用户以为数据没删干净
    await AppDatabase.instance.wipe();
    await refreshAll();
  }
}
