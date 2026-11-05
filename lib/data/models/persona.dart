import 'dart:convert';

/// 画像里的一个侧面（特质）。
class PersonaTrait {
  const PersonaTrait({
    required this.name,
    required this.detail,
    required this.strength,
    required this.evidence,
    required this.trend,
  });

  /// 一句话概括，如「习惯先把情绪收好，再决定要不要说」
  final String name;

  /// 展开解释
  final String detail;

  /// 0..100 显著程度
  final int strength;

  /// 支撑这个判断的原文或事件（必须来自日记）
  final String evidence;

  /// 变强 / 变弱 / 稳定 / 新出现
  final String trend;

  Map<String, Object?> toJson() => {
        'name': name,
        'detail': detail,
        'strength': strength,
        'evidence': evidence,
        'trend': trend,
      };

  static PersonaTrait fromJson(Map<String, Object?> j) => PersonaTrait(
        name: _s(j['name']),
        detail: _s(j['detail']),
        strength: _i(j['strength'], 50).clamp(0, 100),
        evidence: _s(j['evidence']),
        trend: _s(j['trend'], fallback: '稳定'),
      );
}

/// 反复出现的主题。
class PersonaTheme {
  const PersonaTheme({
    required this.name,
    required this.weight,
    required this.note,
  });

  final String name;

  /// 0..100，出现频率与情感浓度综合
  final int weight;
  final String note;

  Map<String, Object?> toJson() => {
        'name': name,
        'weight': weight,
        'note': note,
      };

  static PersonaTheme fromJson(Map<String, Object?> j) => PersonaTheme(
        name: _s(j['name']),
        weight: _i(j['weight'], 50).clamp(0, 100),
        note: _s(j['note']),
      );
}

/// 情绪或行为模式：「当 X 时，你会 Y」。
class PersonaPattern {
  const PersonaPattern({
    required this.trigger,
    required this.response,
    required this.note,
  });

  final String trigger;
  final String response;
  final String note;

  Map<String, Object?> toJson() => {
        'trigger': trigger,
        'response': response,
        'note': note,
      };

  static PersonaPattern fromJson(Map<String, Object?> j) => PersonaPattern(
        trigger: _s(j['trigger']),
        response: _s(j['response']),
        note: _s(j['note']),
      );
}

/// 日记里反复出现的人。
class PersonaPerson {
  const PersonaPerson({
    required this.name,
    required this.role,
    required this.dynamic,
  });

  final String name;
  final String role;

  /// 你与 TA 之间的相处手感
  final String dynamic;

  Map<String, Object?> toJson() => {
        'name': name,
        'role': role,
        'dynamic': dynamic,
      };

  static PersonaPerson fromJson(Map<String, Object?> j) => PersonaPerson(
        name: _s(j['name']),
        role: _s(j['role']),
        dynamic: _s(j['dynamic']),
      );
}

/// 内在矛盾：同时成立的两股力。
class PersonaTension {
  const PersonaTension({
    required this.between,
    required this.detail,
  });

  /// 「想要被看见」与「害怕被看穿」这样的一句话
  final String between;
  final String detail;

  Map<String, Object?> toJson() => {
        'between': between,
        'detail': detail,
      };

  static PersonaTension fromJson(Map<String, Object?> j) => PersonaTension(
        between: _s(j['between']),
        detail: _s(j['detail']),
      );
}

/// 一份关于「你是谁的当前假设」。
/// 刻意叫 Persona 而不是 Profile —— 它是可被推翻的假设，不是档案。
class Persona {
  const Persona({
    required this.version,
    required this.updatedAt,
    required this.entriesCovered,
    required this.summary,
    required this.motto,
    required this.traits,
    required this.themes,
    required this.patterns,
    required this.people,
    required this.tensions,
    required this.blindSpots,
    required this.growthEdges,
    required this.openQuestion,
  });

  final int version;
  final DateTime updatedAt;

  /// 已读过的日记数
  final int entriesCovered;

  /// 两三句话的速写
  final String summary;

  /// 从用户原话里挑的一句，代表此刻的状态
  final String motto;

  final List<PersonaTrait> traits;
  final List<PersonaTheme> themes;
  final List<PersonaPattern> patterns;
  final List<PersonaPerson> people;
  final List<PersonaTension> tensions;

  /// 模型看到但你可能没意识到的
  final List<String> blindSpots;

  /// 正在松动/生长的方向
  final List<String> growthEdges;

  /// 它还没弄明白的一件事 —— 保留不确定性，比假装懂你更可信
  final String openQuestion;

  static Persona empty() => Persona(
        version: 0,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        entriesCovered: 0,
        summary: '',
        motto: '',
        traits: const [],
        themes: const [],
        patterns: const [],
        people: const [],
        tensions: const [],
        blindSpots: const [],
        growthEdges: const [],
        openQuestion: '',
      );

  bool get isEmpty => version == 0 && summary.isEmpty;

  Map<String, Object?> toJson() => {
        'version': version,
        'updated_at': updatedAt.toIso8601String(),
        'entries_covered': entriesCovered,
        'summary': summary,
        'motto': motto,
        'traits': traits.map((e) => e.toJson()).toList(),
        'themes': themes.map((e) => e.toJson()).toList(),
        'patterns': patterns.map((e) => e.toJson()).toList(),
        'people': people.map((e) => e.toJson()).toList(),
        'tensions': tensions.map((e) => e.toJson()).toList(),
        'blind_spots': blindSpots,
        'growth_edges': growthEdges,
        'open_question': openQuestion,
      };

  String toJsonString() => jsonEncode(toJson());

  /// 给「知己」对话用的记忆速写。
  ///
  /// 刻意不用 JSON：把结构化画像整块塞给模型，它就会忍不住逐条表演
  /// （先总结你的特质、再引用你的原话），听起来像在读档案。
  /// 换成几行不完整的印象，更像一个人记得的东西。
  String toMemoryBlock() {
    if (isEmpty) return '（你对 TA 还几乎一无所知，只有零散印象）';

    final b = StringBuffer();
    if (summary.isNotEmpty) b.writeln(summary);

    final strong = [...traits]
      ..sort((a, c) => c.strength.compareTo(a.strength));
    final top = strong.take(4).toList();
    if (top.isNotEmpty) {
      b.writeln();
      b.writeln('你比较有把握的几点：');
      for (final t in top) {
        final detail = t.detail.trim();
        b.writeln('- ${t.name}${detail.isEmpty ? '' : '（$detail）'}');
      }
    }

    if (patterns.isNotEmpty) {
      b.writeln();
      b.writeln('你注意过的一些反复出现的反应：');
      for (final p in patterns.take(3)) {
        b.writeln('- ${p.trigger}，${p.response}');
      }
    }

    if (people.isNotEmpty) {
      b.writeln();
      b.writeln('常出现的人：${people.take(5).map((p) => '${p.name}（${p.role}）').join('、')}');
    }

    if (tensions.isNotEmpty) {
      b.writeln();
      b.writeln('你隐约觉得拧着的地方：${tensions.take(2).map((t) => t.between).join('；')}');
    }

    if (blindSpots.isNotEmpty) {
      b.writeln();
      b.writeln('TA 自己没怎么说过、但一直如此的：${blindSpots.take(2).join('；')}');
    }

    if (motto.isNotEmpty) {
      b.writeln();
      b.writeln('TA 自己写过的一句：$motto');
    }

    if (openQuestion.isNotEmpty) {
      b.writeln();
      b.writeln('你一直没弄明白的：$openQuestion');
    }
    return b.toString().trim();
  }

  /// 容错解析：模型偶尔会少字段、给字符串而不是数组，
  /// 这里一律吞掉异常返回安全默认值，保证读取历史快照永不崩。
  static Persona fromJson(Map<String, Object?> j) {
    List<T> listOf<T>(Object? raw, T Function(Map<String, Object?>) parse) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => parse(e.map((k, v) => MapEntry(k.toString(), v))))
          .toList();
    }

    return Persona(
      version: _i(j['version'], 1),
      updatedAt:
          DateTime.tryParse(_s(j['updated_at'])) ?? DateTime.now(),
      entriesCovered: _i(j['entries_covered'], 0),
      summary: _s(j['summary']),
      motto: _s(j['motto']),
      traits: listOf(j['traits'], PersonaTrait.fromJson),
      themes: listOf(j['themes'], PersonaTheme.fromJson),
      patterns: listOf(j['patterns'], PersonaPattern.fromJson),
      people: listOf(j['people'], PersonaPerson.fromJson),
      tensions: listOf(j['tensions'], PersonaTension.fromJson),
      blindSpots: _stringList(j['blind_spots']),
      growthEdges: _stringList(j['growth_edges']),
      openQuestion: _s(j['open_question']),
    );
  }

  static Persona fromJsonString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return Persona.empty();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Persona.fromJson(
            decoded.map((k, v) => MapEntry(k.toString(), v)));
      }
    } catch (_) {
      // 忽略损坏的快照
    }
    return Persona.empty();
  }
}

// ---------------------------------------------------------------------------
// 防御式取值：LLM 输出不可全信，这里全部兜底。
// ---------------------------------------------------------------------------

String _s(Object? v, {String fallback = ''}) {
  if (v == null) return fallback;
  if (v is String) return v.trim().isEmpty ? fallback : v.trim();
  if (v is List) {
    final joined = v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty);
    return joined.isEmpty ? fallback : joined.join('；');
  }
  return v.toString();
}

int _i(Object? v, int fallback) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}

List<String> _stringList(Object? v) {
  if (v is List) {
    return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
  }
  if (v is String && v.trim().isNotEmpty) return [v.trim()];
  return const [];
}
