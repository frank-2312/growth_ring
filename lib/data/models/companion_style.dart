import 'dart:convert';

/// 它和你的关系。
///
/// 关系决定了很多东西：能不能开玩笑、要不要客套、说话能有多随便。
/// 所以这个不是装饰项，它会直接进 prompt。
enum CompanionRelation {
  oldFriend(
    '老相识',
    '认识很多年，说话不用铺垫',
    '你和 TA 认识很多年，久到不用寒暄。开口就能接上话，沉默也不尴尬。',
  ),
  penPal(
    '笔友',
    '隔着一点距离，靠文字来往',
    '你和 TA 是长期通信的关系。不常见面，但写下来的话都算数，语气里带一点距离感。',
  ),
  neighbor(
    '隔壁的人',
    '住得近，碰见就聊两句',
    '你像住在 TA 隔壁的人。碰上了就说几句，不必每次都聊到深处，也不必装作很懂 TA。',
  ),
  senior(
    '年长几岁',
    '见过一些事，但不摆架子',
    '你比 TA 年长几岁，见过一些事，说话可以稳一点，但不摆长辈架子，也不说教。',
  ),
  stranger(
    '刚认识',
    '还在互相试探',
    '你和 TA 刚认识不久，还在互相试探。不要假装熟悉，也不要急着显得懂 TA。',
  );

  const CompanionRelation(this.label, this.hint, this.prompt);

  final String label;
  final String hint;

  /// 直接写进 system prompt 的一句关系描述
  final String prompt;

  static CompanionRelation fromName(String? raw) {
    for (final r in values) {
      if (r.name == raw) return r;
    }
    return CompanionRelation.oldFriend;
  }
}

/// 「知己」该长成什么样。
///
/// 注意它和 Persona 的分工：
/// - Persona 是它对「你」的理解，模型写，你只能读；
/// - CompanionStyle 是它的自我设定，你写，模型照做。
///
/// 分开的好处是：画像更新不会把你自己调好的口气冲掉。
class CompanionStyle {
  const CompanionStyle({
    this.name = '',
    this.relation = CompanionRelation.oldFriend,
    this.warmth = 55,
    this.directness = 65,
    this.talkativeness = 40,
    this.pushback = 55,
    this.humor = 40,
    this.memory = 30,
    this.note = '',
  });

  /// 它叫什么。留空就不特意起名。
  final String name;
  final CompanionRelation relation;

  /// 下面六个维度都是 0..100，越高越偏向后者。
  final int warmth;
  final int directness;
  final int talkativeness;
  final int pushback;
  final int humor;

  /// 提旧事的频率。这是最容易把它变成「背档案机器」的旋钮，所以单独给你。
  final int memory;

  /// 你额外交代的话，原样进 prompt
  final String note;

  String get displayName => name.trim().isEmpty ? '它' : name.trim();

  CompanionStyle copyWith({
    String? name,
    CompanionRelation? relation,
    int? warmth,
    int? directness,
    int? talkativeness,
    int? pushback,
    int? humor,
    int? memory,
    String? note,
  }) =>
      CompanionStyle(
        name: name ?? this.name,
        relation: relation ?? this.relation,
        warmth: warmth ?? this.warmth,
        directness: directness ?? this.directness,
        talkativeness: talkativeness ?? this.talkativeness,
        pushback: pushback ?? this.pushback,
        humor: humor ?? this.humor,
        memory: memory ?? this.memory,
        note: note ?? this.note,
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'relation': relation.name,
        'warmth': warmth,
        'directness': directness,
        'talkativeness': talkativeness,
        'pushback': pushback,
        'humor': humor,
        'memory': memory,
        'note': note,
      };

  String toJsonString() => jsonEncode(toJson());

  static CompanionStyle fromJsonString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const CompanionStyle();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return CompanionStyle.fromJson(
            decoded.map((k, v) => MapEntry(k.toString(), v)));
      }
    } catch (_) {
      // 配置坏了就退回默认，不要因此打不开应用
    }
    return const CompanionStyle();
  }

  static CompanionStyle fromJson(Map<String, Object?> j) => CompanionStyle(
        name: _s(j['name']),
        relation: CompanionRelation.fromName(_s(j['relation'])),
        warmth: _i(j['warmth'], 55),
        directness: _i(j['directness'], 65),
        talkativeness: _i(j['talkativeness'], 40),
        pushback: _i(j['pushback'], 55),
        humor: _i(j['humor'], 40),
        memory: _i(j['memory'], 30),
        note: _s(j['note']),
      );

  /// 喂给模型的性格说明。用自然语言而不是 JSON：
  /// 结构化字段会让模型倾向于逐条表演，散文式的交代更像在给人提要求。
  String toPromptBlock() {
    final b = StringBuffer();
    if (name.trim().isNotEmpty) {
      b.writeln('你叫「${name.trim()}」。TA 就这么叫你，你也知道这是自己。');
    } else {
      b.writeln('你没有特别的名字，TA 不会用名字叫你。不要自我介绍。');
    }
    b.writeln(relation.prompt);
    b.writeln();
    b.writeln('温度：${_band(warmth,
        '偏冷。你不主动安慰，也不假装关心。语气平，句子短，不铺垫情绪。',
        '正常。你接得住 TA 的情绪，但不夸张、不腻，说完就完。',
        '偏热。你会显得亲近，关心就直说，但别哄，别把话说得像糖。')}');
    b.writeln('直白：${_band(directness,
        '留余地。会绕着说，先照顾感受再讲观点。',
        '该说就说，不为难也不绕。',
        '很直。想到什么说什么，不修饰，不怕让 TA 当下不舒服。')}');
    b.writeln('话量：${_band(talkativeness,
        '话少。一句就够，甚至几个字。「嗯」「是吗」「那挺烦的」都算完整回复。不解释，不铺垫。',
        '正常。两到四句，说完就停，不硬撑长度。',
        '话偏多。会自己展开、举例、扯到别处，但别变成讲座，也别一直占着话头。')}');
    b.writeln('顶嘴：${_band(pushback,
        '很少反驳。不同意也轻轻放过，先顺着理解。',
        '该顶的时候顶一下，讲清理由就收。',
        '会顶。TA 说得不对或者明显在自欺，你直接说「我不这么看」，但不动气、不羞辱。')}');
    b.writeln('幽默：${_band(humor,
        '基本不开玩笑，认真说话。',
        '偶尔一句轻的，不刻意逗笑。',
        '会开玩笑、会自嘲、会指出事情荒诞的地方。但别用玩笑挡掉正经话。')}');
    b.writeln('提旧事：${_band(memory,
        '几乎不提。只有 TA 主动问起，你才动用日记里的东西；其余时候像个刚熟起来的人。',
        '偶尔提。一轮对话里最多一次，而且必须和眼下这句话真的接得上。',
        '可以常提。但每次都要和当前话题有关，不是找机会展示你读过什么。')}');
    if (note.trim().isNotEmpty) {
      b.writeln();
      b.writeln('TA 另外交代过（优先于上面的默认倾向）：${note.trim()}');
    }
    return b.toString().trim();
  }

  static String _band(int v, String low, String mid, String high) {
    if (v < 35) return low;
    if (v <= 65) return mid;
    return high;
  }
}

/// 几套现成的脾气。点一下就填好滑杆，之后还能再改。
class CompanionPreset {
  const CompanionPreset(this.label, this.hint, this.style);

  final String label;
  final String hint;
  final CompanionStyle style;

  static const List<CompanionPreset> all = [
    CompanionPreset(
      '老友',
      '不客气，偶尔损你两句',
      CompanionStyle(
        relation: CompanionRelation.oldFriend,
        warmth: 60,
        directness: 75,
        talkativeness: 45,
        pushback: 65,
        humor: 55,
        memory: 35,
      ),
    ),
    CompanionPreset(
      '旁观的人',
      '话少，不掺和，看得清',
      CompanionStyle(
        relation: CompanionRelation.penPal,
        warmth: 30,
        directness: 85,
        talkativeness: 25,
        pushback: 60,
        humor: 20,
        memory: 15,
      ),
    ),
    CompanionPreset(
      '温和的听者',
      '先接住，再说话',
      CompanionStyle(
        relation: CompanionRelation.senior,
        warmth: 85,
        directness: 35,
        talkativeness: 45,
        pushback: 20,
        humor: 25,
        memory: 25,
      ),
    ),
    CompanionPreset(
      '不留情面',
      '专戳你绕开的地方',
      CompanionStyle(
        relation: CompanionRelation.oldFriend,
        warmth: 45,
        directness: 95,
        talkativeness: 50,
        pushback: 90,
        humor: 70,
        memory: 30,
      ),
    ),
  ];
}

String _s(Object? v) => v == null ? '' : v.toString().trim();

int _i(Object? v, int fallback) {
  if (v is int) return v.clamp(0, 100);
  if (v is num) return v.round().clamp(0, 100);
  if (v is String) return (int.tryParse(v.trim()) ?? fallback).clamp(0, 100);
  return fallback;
}
