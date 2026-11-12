import 'dart:convert';

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
    this.photos = const [],
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

  /// 配图文件名（不含目录）。真实路径是 `photos/<dateKey>/<name>`，
  /// 文件名而不是绝对路径存进库，换设备恢复备份时目录变了也不会失效。
  final List<String> photos;

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

  /// 只有图没有字的日记也是一篇——用户拍下来了，就是记下了
  bool get isEmpty => content.trim().isEmpty && photos.isEmpty;

  bool get hasPhotos => photos.isNotEmpty;

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
    List<String>? photos,
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
      photos: photos ?? this.photos,
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
        'photos': jsonEncode(photos),
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
      photos: _decodePhotos(m['photos']),
      echo: m['echo'] as String?,
      analyzed: (m['analyzed'] as int?) == 1,
    );
  }

  /// v1 的库没有这一列（迁移后是 NULL），坏掉的 JSON 也不该让整篇日记打不开
  static List<String> _decodePhotos(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final e in decoded)
          if (e is String && e.trim().isNotEmpty) e.trim(),
      ];
    } catch (_) {
      return const [];
    }
  }
}
