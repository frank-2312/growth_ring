import 'dart:math' as math;

import '../core/fmt.dart';
import '../data/models/diary_entry.dart';
import '../data/models/entry_digest.dart';
import '../data/models/insight.dart';
import '../data/models/persona.dart';
import '../data/repositories/diary_repository.dart';
import '../data/repositories/persona_repository.dart';
import 'llm_client.dart';
import 'prompts.dart';

/// 一次反思的结果，供界面告诉用户「刚才发生了什么」
class ReflectResult {
  const ReflectResult({
    required this.persona,
    required this.insights,
    required this.changes,
    required this.digested,
    required this.remaining,
  });

  final Persona persona;
  final List<Insight> insights;
  final List<String> changes;
  final int digested;

  /// 还没读的篇数（单次有上限，避免一次烧掉太多额度）
  final int remaining;

  bool get changed => changes.isNotEmpty || insights.isNotEmpty;
}

class ReflectException implements Exception {
  ReflectException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 把「日记」变成「了解」的那台机器。
///
/// 流程刻意拆成两步：先把每篇读成事实（digest），再拿事实去更新假设（merge）。
/// 好处是重算画像不必重读原文，也方便单独检查模型到底从哪句话里得出了什么。
class PersonaEngine {
  PersonaEngine({
    required this.client,
    required this.diary,
    required this.personas,
  });

  final LlmClient client;
  final DiaryRepository diary;
  final PersonaRepository personas;

  /// 单次最多读几篇。太多会一次花掉大量额度，也更容易让模型把细节糊掉。
  static const int maxBatch = 6;

  /// 少于这个字数的日记不送模型：一句「今天累」榨不出什么，还浪费 token
  static const int minChars = 10;

  Future<ReflectResult> reflect({
    required Persona current,
    required String nickname,
    void Function(String stage, int done, int total)? onProgress,
  }) async {
    final all = await diary.pendingAnalysis();
    if (all.isEmpty) {
      return ReflectResult(
        persona: current,
        insights: const [],
        changes: const ['没有新的日记需要读。'],
        digested: 0,
        remaining: 0,
      );
    }

    // 太短的直接跳过，不占用批次也不花钱
    final tooShort = all
        .where((e) => e.content.trim().length < minChars)
        .map((e) => e.id)
        .toList();
    if (tooShort.isNotEmpty) {
      await diary.markSkipped(tooShort);
    }

    final candidates = all.where((e) => !tooShort.contains(e.id)).toList();
    if (candidates.isEmpty) {
      return ReflectResult(
        persona: current,
        insights: const [],
        changes: const ['新日记都太短了，没读。'],
        digested: 0,
        remaining: 0,
      );
    }

    final batch = candidates.take(maxBatch).toList();
    final remaining = candidates.length - batch.length;

    final digests = <EntryDigest>[];
    final okIds = <String>[];
    Object? lastError;

    for (var i = 0; i < batch.length; i++) {
      final entry = batch[i];
      onProgress?.call('正在读 ${Fmt.monthDay(entry.date)}', i, batch.length);
      try {
        final json = await client.completeJson(
          Prompts.digest(entry),
          temperature: 0.2,
          maxTokens: 1200,
          timeout: const Duration(seconds: 120),
        );
        final digest = EntryDigest.fromJson({
          ...json,
          'date': entry.dateKey, // 日期以本地为准，防止模型改写
        });
        await diary.saveDigest(digest);
        digests.add(digest);
        okIds.add(entry.id);
      } catch (e) {
        lastError = e;
      }
    }

    if (digests.isEmpty) {
      throw ReflectException(
        '这几篇都没读成。${lastError ?? ''}\n检查一下网络和模型配置，然后再试。',
      );
    }

    onProgress?.call('正在重新认识你', batch.length, batch.length);

    final Map<String, Object?> merged;
    try {
      merged = await client.completeJson(
        Prompts.mergePersona(
          previous: current,
          digests: digests,
          nickname: nickname,
        ),
        temperature: 0.5,
        maxTokens: 4096,
        timeout: const Duration(seconds: 240),
      );
    } catch (e) {
      // 读解结果已经落库，下次只需重跑合并，不必重付读解成本
      throw ReflectException('读完了，但整理画像时出错：$e');
    }

    final persona = _buildPersona(
      merged: merged,
      previous: current,
      covered: digests.length,
    );
    await personas.save(persona);

    final insights = _parseInsights(merged, digests);
    if (insights.isNotEmpty) {
      await personas.addInsights(insights);
    }

    await diary.markAnalyzed(okIds);

    return ReflectResult(
      persona: persona,
      insights: insights,
      changes: _parseStringList(merged['changes']),
      digested: digests.length,
      remaining: remaining,
    );
  }

  /// 当日回声：轻量、即时，不带评价
  Future<String?> echo({
    required DiaryEntry entry,
    required Persona persona,
    required String nickname,
  }) async {
    if (entry.content.trim().length < 6) return null;
    try {
      final text = await client.complete(
        Prompts.echo(entry: entry, persona: persona, nickname: nickname),
        temperature: 0.8,
        maxTokens: 160,
        timeout: const Duration(seconds: 45),
      );
      final clean = text.trim().replaceAll(RegExp(r'^["「『]|["」』]$'), '');
      return clean.isEmpty ? null : clean;
    } catch (_) {
      // 回声失败不影响写日记这件事本身
      return null;
    }
  }

  /// 阶段回望
  Future<String> retrospective({
    required Persona persona,
    required String nickname,
    int days = 30,
  }) async {
    final digests = await diary.recentDigests(limit: days);
    if (digests.isEmpty) {
      throw ReflectException('还没有足够的内容可以回望，先写上几天。');
    }
    return client.complete(
      Prompts.retrospective(
        persona: persona,
        digests: digests,
        nickname: nickname,
      ),
      temperature: 0.7,
      maxTokens: 900,
      timeout: const Duration(seconds: 150),
    );
  }

  // --- 内部 ---------------------------------------------------------------

  Persona _buildPersona({
    required Map<String, Object?> merged,
    required Persona previous,
    required int covered,
  }) {
    return Persona.fromJson({
      ...merged,
      'version': previous.version + 1,
      'updated_at': DateTime.now().toIso8601String(),
      'entries_covered': previous.entriesCovered + covered,
    });
  }

  List<Insight> _parseInsights(
      Map<String, Object?> merged, List<EntryDigest> digests) {
    final raw = merged['insights'];
    if (raw is! List) return const [];
    final latestDate =
        digests.isEmpty ? Fmt.dateKey(DateTime.now()) : digests.last.dateKey;
    final validDates = digests.map((d) => d.dateKey).toSet();

    final out = <Insight>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = item.map((k, v) => MapEntry(k.toString(), v));
      final title = (map['title'] ?? '').toString().trim();
      final body = (map['body'] ?? '').toString().trim();
      if (title.isEmpty && body.isEmpty) continue;
      var dateKey = (map['date'] ?? '').toString().trim();
      if (!validDates.contains(dateKey)) dateKey = latestDate;
      out.add(Insight(
        id: newIdFromClock() + out.length.toString(),
        createdAt: DateTime.now(),
        dateKey: dateKey,
        title: title.isEmpty ? Fmt.ellipsis(body, 20) : title,
        body: body,
        quote: (map['quote']?.toString().trim().isEmpty ?? true)
            ? null
            : map['quote'].toString().trim(),
      ));
      if (out.length >= 5) break;
    }
    return out;
  }

  List<String> _parseStringList(Object? raw) {
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .take(5)
          .toList();
    }
    if (raw is String && raw.trim().isNotEmpty) return [raw.trim()];
    return const [];
  }

  /// 给界面用的：估算还需要几轮才能读完
  static int roundsFor(int pending) =>
      pending <= 0 ? 1 : (pending / maxBatch).ceil().clamp(1, 1 << 30);

  /// 画像完成度：0..1，按已读篇数温和收敛，用来画那个环
  static double completeness(int covered) {
    if (covered <= 0) return 0;
    return (1 - math.exp(-covered / 12)).clamp(0.0, 0.97);
  }
}
