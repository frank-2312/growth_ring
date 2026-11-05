/// 模型对单篇日记的结构化读取结果。
/// 这一层只负责「事实提取」，不下判断，判断留给画像合并时做。
class EntryDigest {
  const EntryDigest({
    required this.dateKey,
    required this.mood,
    required this.moodScore,
    required this.energy,
    required this.events,
    required this.themes,
    required this.people,
    required this.selfStatements,
    required this.tensions,
    required this.quotes,
  });

  final String dateKey;

  /// 情绪词，两三个字
  final String mood;

  /// -3..3，负为沉，正为扬
  final int moodScore;

  /// 1..5 精力
  final int energy;

  /// 发生了什么（白描句）
  final List<String> events;

  /// 涉及的主题/领域，如「工作」「家人」「自我怀疑」
  final List<String> themes;

  /// 提到的人及其关系线索
  final List<String> people;

  /// 自我陈述，尤其是「我总是…」「我不应该…」这类
  final List<String> selfStatements;

  /// 同一篇里显露的矛盾
  final List<String> tensions;

  /// 值得留存的原文片段（用于日后引用，必须逐字摘录）
  final List<String> quotes;

  Map<String, Object?> toJson() => {
        'date': dateKey,
        'mood': mood,
        'mood_score': moodScore,
        'energy': energy,
        'events': events,
        'themes': themes,
        'people': people,
        'self_statements': selfStatements,
        'tensions': tensions,
        'quotes': quotes,
      };

  static EntryDigest fromJson(Map<String, Object?> j) {
    int asInt(Object? v, int fallback) {
      if (v is int) return v;
      if (v is num) return v.round();
      if (v is String) return int.tryParse(v.trim()) ?? fallback;
      return fallback;
    }

    List<String> asList(Object? v) {
      if (v is List) {
        return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      if (v is String && v.trim().isNotEmpty) return [v.trim()];
      return const [];
    }

    return EntryDigest(
      dateKey: (j['date'] ?? '').toString(),
      mood: (j['mood'] ?? '说不清').toString(),
      moodScore: asInt(j['mood_score'], 0).clamp(-3, 3),
      energy: asInt(j['energy'], 3).clamp(1, 5),
      events: asList(j['events']),
      themes: asList(j['themes']),
      people: asList(j['people']),
      selfStatements: asList(j['self_statements']),
      tensions: asList(j['tensions']),
      quotes: asList(j['quotes']),
    );
  }

  /// 喂给画像合并的紧凑文本，控制 token
  String toPromptBlock() {
    final b = StringBuffer()
      ..writeln('[$dateKey] 情绪:$mood($moodScore) 精力:$energy');
    if (themes.isNotEmpty) b.writeln('  主题: ${themes.join('、')}');
    if (events.isNotEmpty) b.writeln('  事件: ${events.join('；')}');
    if (people.isNotEmpty) b.writeln('  人物: ${people.join('、')}');
    if (selfStatements.isNotEmpty) {
      b.writeln('  自我陈述: ${selfStatements.join(' / ')}');
    }
    if (tensions.isNotEmpty) b.writeln('  张力: ${tensions.join('；')}');
    if (quotes.isNotEmpty) b.writeln('  原话: ${quotes.join(' / ')}');
    return b.toString();
  }
}
