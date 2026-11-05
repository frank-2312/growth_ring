/// 一天的日记。一日一篇：日期是逻辑主键，
/// 这样「今天」这件事才成立，也让画像的时间轴不会因为同天多篇而挤在一起。
class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.dateKey,
    required this.createdAt,
    required this.updatedAt,
    required this.content,
    this.title,
    this.mood,
    this.energy,
    this.tags = const [],
    this.echo,
    this.analyzed = false,
  });

  final String id;

  /// yyyy-MM-dd
  final String dateKey;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String content;

  /// 用户没写标题时由正文首句推导，仅用于展示
  final String? title;

  /// 自评情绪词，如「平静」「烦」
  final String? mood;

  /// 精力 1..5
  final int? energy;

  final List<String> tags;

  /// 保存后模型给的一句回声，不是评价，只是照见
  final String? echo;

  /// 是否已纳入画像
  final bool analyzed;

  DateTime get date {
    final parts = dateKey.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  bool get isEmpty => content.trim().isEmpty;

  DiaryEntry copyWith({
    String? id,
    String? dateKey,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? content,
    String? title,
    String? mood,
    int? energy,
    List<String>? tags,
    String? echo,
    bool? analyzed,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      dateKey: dateKey ?? this.dateKey,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      content: content ?? this.content,
      title: title ?? this.title,
      mood: mood ?? this.mood,
      energy: energy ?? this.energy,
      tags: tags ?? this.tags,
      echo: echo ?? this.echo,
      analyzed: analyzed ?? this.analyzed,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'date_key': dateKey,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'content': content,
        'title': title,
        'mood': mood,
        'energy': energy,
        'tags': tags.join('\u0001'),
        'echo': echo,
        'analyzed': analyzed ? 1 : 0,
      };

  static DiaryEntry fromMap(Map<String, Object?> m) {
    final tagsRaw = (m['tags'] as String?) ?? '';
    return DiaryEntry(
      id: m['id'] as String,
      dateKey: m['date_key'] as String,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch((m['created_at'] as int?) ?? 0),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch((m['updated_at'] as int?) ?? 0),
      content: (m['content'] as String?) ?? '',
      title: m['title'] as String?,
      mood: m['mood'] as String?,
      energy: m['energy'] as int?,
      tags: tagsRaw.isEmpty ? const [] : tagsRaw.split('\u0001'),
      echo: m['echo'] as String?,
      analyzed: (m['analyzed'] as int?) == 1,
    );
  }
}
