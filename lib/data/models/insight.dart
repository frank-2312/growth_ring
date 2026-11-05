/// 画像演进时产出的单条洞察。
/// 与 Persona 的区别：Persona 是「当前结论」，Insight 是「何时因为什么而改变」。
class Insight {
  const Insight({
    required this.id,
    required this.createdAt,
    required this.dateKey,
    required this.title,
    required this.body,
    this.quote,
  });

  final String id;
  final DateTime createdAt;

  /// 归属的日记日期，用于在时光轴里对齐
  final String dateKey;

  /// 一句话发现
  final String title;

  /// 展开
  final String body;

  /// 日记里的原话
  final String? quote;

  Map<String, Object?> toMap() => {
        'id': id,
        'created_at': createdAt.millisecondsSinceEpoch,
        'date_key': dateKey,
        'title': title,
        'body': body,
        'quote': quote,
      };

  static Insight fromMap(Map<String, Object?> m) => Insight(
        id: m['id'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch((m['created_at'] as int?) ?? 0),
        dateKey: (m['date_key'] as String?) ?? '',
        title: (m['title'] as String?) ?? '',
        body: (m['body'] as String?) ?? '',
        quote: m['quote'] as String?,
      );

  static Insight fromJson(Map<String, Object?> j, String dateKey) => Insight(
        id: newIdFromClock(),
        createdAt: DateTime.now(),
        dateKey: dateKey,
        title: (j['title'] ?? '').toString().trim(),
        body: (j['body'] ?? '').toString().trim(),
        quote: (j['quote']?.toString().trim().isEmpty ?? true)
            ? null
            : j['quote'].toString().trim(),
      );

  Map<String, Object?> toJson() => {
        'title': title,
        'body': body,
        'quote': quote,
      };
}

String newIdFromClock() =>
    'i${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
