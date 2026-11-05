import 'dart:math';

/// 统一的时间与文本处理。刻意不依赖 intl 的 locale 数据，
/// 避免运行期忘记 initializeDateFormatting 导致中文格式化崩溃。
class Fmt {
  const Fmt._();

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  /// 2026-11-04
  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// 11月4日
  static String monthDay(DateTime d) => '${d.month}月${d.day}日';

  /// 2026年11月4日
  static String fullDate(DateTime d) =>
      '${d.year}年${d.month}月${d.day}日';

  /// 周三
  static String weekday(DateTime d) => '周${_weekdays[d.weekday - 1]}';

  /// 2026年11月4日 周三
  static String fullDateWithWeek(DateTime d) =>
      '${fullDate(d)} ${weekday(d)}';

  /// 18:09
  static String clock(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  /// 刚刚 / 3 分钟前 / 昨天 / 11月4日
  static String relative(DateTime d, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final diff = ref.difference(d);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24 && dateKey(ref) == dateKey(d)) {
      return '${diff.inHours} 小时前';
    }
    final days = DateTime(ref.year, ref.month, ref.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (days == 1) return '昨天';
    if (days == 2) return '前天';
    if (days < 7) return '$days 天前';
    if (d.year == ref.year) return monthDay(d);
    return fullDate(d);
  }

  /// 把日期归到「今天/昨天/更早」
  static String dayBucket(DateTime d, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final days = DateTime(ref.year, ref.month, ref.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (days <= 0) return '今天';
    if (days == 1) return '昨天';
    if (days < 7) return '这周';
    if (days < 31) return '这个月';
    if (d.year == ref.year) return '${d.month} 月';
    return '${d.year} 年';
  }

  /// 中文按字计，英文按词计，混合时两者相加，接近字数统计的直觉。
  static int wordCount(String text) {
    if (text.trim().isEmpty) return 0;
    final cjk = RegExp(r'[\u4e00-\u9fa5\u3400-\u4dbf]');
    final latin = RegExp(r'[A-Za-z0-9]+');
    return cjk.allMatches(text).length + latin.allMatches(text).length;
  }

  /// 从正文里抽一句适合做标题的话
  static String? deriveTitle(String content) {
    for (final raw in content.split('\n')) {
      final line = raw.trim().replaceAll(RegExp(r'^[#>\-\*\s]+'), '');
      if (line.isEmpty) continue;
      final firstClause = line.split(RegExp(r'[。！？!?\n]')).first.trim();
      if (firstClause.isEmpty) continue;
      return firstClause.length > 24
          ? '${firstClause.substring(0, 24)}…'
          : firstClause;
    }
    return null;
  }

  /// 摘要用：截断但尽量停在标点后
  static String ellipsis(String text, int max) {
    final clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= max) return clean;
    final cut = clean.substring(0, max);
    final lastPunct = cut.lastIndexOf(RegExp(r'[。，、；！？,.;!?]'));
    if (lastPunct > max * 0.5) return '${cut.substring(0, lastPunct + 1)}…';
    return '$cut…';
  }
}

/// 轻量 id：时间戳 + 随机后缀，足够本地单机使用，不引入 uuid 依赖。
String newId([String prefix = '']) {
  final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final rnd = Random().nextInt(1679615).toRadixString(36).padLeft(4, '0');
  return '$prefix$ts$rnd';
}
