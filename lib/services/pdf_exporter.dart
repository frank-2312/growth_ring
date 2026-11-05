import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/fmt.dart';
import '../data/models/diary_entry.dart';
import '../data/models/insight.dart';
import '../data/models/persona.dart';

/// 纸张尺寸。日记本用 A5 更像书，需要打印归档时用 A4。
enum ExportPaper { a5, a4 }

class ExportOptions {
  const ExportOptions({
    this.paper = ExportPaper.a5,
    this.includePersona = true,
    this.includeInsights = true,
    this.includeEcho = true,
    this.onlyDateKeys,
  });

  final ExportPaper paper;

  /// 附上「它眼中的你」章节
  final bool includePersona;

  /// 附上洞察时间线
  final bool includeInsights;
  final bool includeEcho;

  /// null 表示全部；否则只导出这些日期
  final Set<String>? onlyDateKeys;

  ExportOptions copyWith({
    ExportPaper? paper,
    bool? includePersona,
    bool? includeInsights,
    bool? includeEcho,
    Set<String>? onlyDateKeys,
  }) =>
      ExportOptions(
        paper: paper ?? this.paper,
        includePersona: includePersona ?? this.includePersona,
        includeInsights: includeInsights ?? this.includeInsights,
        includeEcho: includeEcho ?? this.includeEcho,
        onlyDateKeys: onlyDateKeys ?? this.onlyDateKeys,
      );
}

/// 生成可打印的 PDF。
///
/// 中文字体是从 assets 里读出来的 TTF：pdf 包不认识系统字体，
/// 不嵌入字体的话中文会整页变方块——这是这类需求最常见的坑。
class PdfExporter {
  static pw.Font? _cached;

  static Future<pw.Font> _font() async {
    if (_cached != null) return _cached!;
    final data = await rootBundle.load('assets/fonts/LXGWWenKai-Regular.ttf');
    final font = pw.Font.ttf(data);
    _cached = font;
    return font;
  }

  static const _ink = PdfColor.fromInt(0xFF2A2622);
  static const _inkSoft = PdfColor.fromInt(0xFF7A7167);
  static const _hairline = PdfColor.fromInt(0xFFDCD3C6);
  static const _paper = PdfColor.fromInt(0xFFFDFBF7);
  static const _amber = PdfColor.fromInt(0xFF8A6B34);

  static Future<Uint8List> build({
    required List<DiaryEntry> entries,
    required Persona persona,
    required List<Insight> insights,
    required String nickname,
    ExportOptions options = const ExportOptions(),
  }) async {
    final font = await _font();
    final format =
        options.paper == ExportPaper.a4 ? PdfPageFormat.a4 : PdfPageFormat.a5;

    final picked = (options.onlyDateKeys == null
            ? entries
            : entries.where((e) => options.onlyDateKeys!.contains(e.dateKey)))
        .where((e) => e.content.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.dateKey.compareTo(b.dateKey));

    final doc = pw.Document(
      title: '年轮 · 日记',
      author: nickname.isEmpty ? '年轮' : nickname,
      creator: '年轮',
      subject: '日记选集',
      theme: pw.ThemeData.withFont(
        base: font,
        bold: font,
        italic: font,
        boldItalic: font,
        fontFallback: [font],
      ),
    );

    _addCover(
      doc: doc,
      format: format,
      entries: picked,
      persona: persona,
      nickname: nickname,
    );

    if (picked.isNotEmpty) {
      _addDiaryBody(
        doc: doc,
        format: format,
        entries: picked,
        options: options,
      );
    }

    if (options.includePersona && !persona.isEmpty) {
      _addPersonaSection(doc: doc, format: format, persona: persona);
    }

    if (options.includeInsights && insights.isNotEmpty) {
      _addInsightsSection(doc: doc, format: format, insights: insights);
    }

    _addColophon(doc: doc, format: format);

    return doc.save();
  }

  // --- 封面 ---------------------------------------------------------------

  static void _addCover({
    required pw.Document doc,
    required PdfPageFormat format,
    required List<DiaryEntry> entries,
    required Persona persona,
    required String nickname,
  }) {
    final first = entries.isEmpty ? null : entries.first.date;
    final last = entries.isEmpty ? null : entries.last.date;
    final who = nickname.trim();

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Container(
          color: _paper,
          padding: const pw.EdgeInsets.fromLTRB(52, 68, 52, 48),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '年 轮',
                style: pw.TextStyle(
                  fontSize: 34,
                  color: _ink,
                  letterSpacing: 8,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(width: 40, height: 1.4, color: _amber),
              pw.SizedBox(height: 26),
              pw.Text(
                who.isEmpty ? '一本日记' : '$who 的日记',
                style: const pw.TextStyle(fontSize: 14, color: _inkSoft),
              ),
              pw.SizedBox(height: 6),
              if (first != null && last != null)
                pw.Text(
                  first.year == last.year
                      ? '${first.year} 年 ${first.month} 月 — ${last.month} 月'
                      : '${Fmt.fullDate(first)} — ${Fmt.fullDate(last)}',
                  style: const pw.TextStyle(fontSize: 12, color: _inkSoft),
                ),
              pw.SizedBox(height: 4),
              pw.Text(
                '共 ${entries.length} 篇',
                style: const pw.TextStyle(fontSize: 12, color: _inkSoft),
              ),
              pw.Spacer(),
              if (persona.summary.isNotEmpty) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(18),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      left: pw.BorderSide(color: _amber, width: 2),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '这一刻的你',
                        style: const pw.TextStyle(fontSize: 9, color: _inkSoft),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        persona.summary,
                        style: const pw.TextStyle(
                          fontSize: 12.5,
                          color: _ink,
                          lineSpacing: 6,
                        ),
                      ),
                      if (persona.motto.isNotEmpty) ...[
                        pw.SizedBox(height: 10),
                        pw.Text(
                          '「${persona.motto}」',
                          style: const pw.TextStyle(
                            fontSize: 11,
                            color: _inkSoft,
                            lineSpacing: 4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              pw.SizedBox(height: 18),
              pw.Text(
                '由「年轮」导出 · ${Fmt.fullDate(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 8.5, color: _inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 正文 ---------------------------------------------------------------

  static void _addDiaryBody({
    required pw.Document doc,
    required PdfPageFormat format,
    required List<DiaryEntry> entries,
    required ExportOptions options,
  }) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.fromLTRB(48, 54, 48, 52),
        header: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 14),
          child: pw.Text(
            '年 轮',
            style: const pw.TextStyle(
              fontSize: 8.5,
              color: _inkSoft,
              letterSpacing: 2,
            ),
          ),
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            '${ctx.pageNumber}',
            style: const pw.TextStyle(fontSize: 8.5, color: _inkSoft),
          ),
        ),
        build: (ctx) {
          final widgets = <pw.Widget>[];
          String? currentMonth;

          for (var i = 0; i < entries.length; i++) {
            final e = entries[i];
            final month = '${e.date.year} 年 ${e.date.month} 月';
            if (month != currentMonth) {
              currentMonth = month;
              widgets.add(pw.SizedBox(height: i == 0 ? 0 : 30));
              widgets.add(_monthHeader(month));
            }

            widgets.add(pw.SizedBox(height: 20));
            widgets.add(_entryBlock(e, options));
          }
          return widgets;
        },
      ),
    );
  }

  static pw.Widget _monthHeader(String month) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            month,
            style: pw.TextStyle(
              fontSize: 15,
              color: _amber,
              letterSpacing: 2,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(height: 0.7, color: _hairline),
        ],
      );

  static pw.Widget _entryBlock(DiaryEntry e, ExportOptions options) {
    final meta = <String>[
      Fmt.monthDay(e.date),
      Fmt.weekday(e.date),
      if (e.mood != null && e.mood!.isNotEmpty) e.mood!,
      if (e.energy != null) '精力 ${e.energy}/5',
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              '${e.date.day}',
              style: pw.TextStyle(fontSize: 20, color: _ink),
            ),
            pw.SizedBox(width: 8),
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(
                meta.skip(1).join(' · '),
                style: const pw.TextStyle(fontSize: 8.5, color: _inkSoft),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          e.content.trim(),
          style: const pw.TextStyle(
            fontSize: 11,
            color: _ink,
            lineSpacing: 5.5,
          ),
        ),
        if (options.includeEcho && (e.echo?.isNotEmpty ?? false)) ...[
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.only(left: 10),
            decoration: pw.BoxDecoration(
              border: pw.Border(left: pw.BorderSide(color: _amber, width: 1.6)),
            ),
            child: pw.Text(
              e.echo!,
              style: const pw.TextStyle(
                fontSize: 9.5,
                color: _inkSoft,
                lineSpacing: 4,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // --- 画像 ---------------------------------------------------------------

  static void _addPersonaSection({
    required pw.Document doc,
    required PdfPageFormat format,
    required Persona persona,
  }) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.fromLTRB(48, 54, 48, 52),
        build: (ctx) => [
          pw.SizedBox(height: 10),
          pw.Text(
            '它眼中的你',
            style: pw.TextStyle(fontSize: 18, color: _ink, letterSpacing: 3),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '基于 ${persona.entriesCovered} 篇日记的观察，第 ${persona.version} 版',
            style: const pw.TextStyle(fontSize: 8.5, color: _inkSoft),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            persona.summary,
            style: const pw.TextStyle(
              fontSize: 11.5,
              color: _ink,
              lineSpacing: 6,
            ),
          ),
          if (persona.motto.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              '「${persona.motto}」',
              style: const pw.TextStyle(fontSize: 10, color: _inkSoft),
            ),
          ],
          if (persona.traits.isNotEmpty) ...[
            pw.SizedBox(height: 24),
            _subHeading('性格里的几处'),
            ...persona.traits.map((t) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(t.name,
                          style: pw.TextStyle(fontSize: 11, color: _ink)),
                      pw.SizedBox(height: 3),
                      pw.Text(t.detail,
                          style: const pw.TextStyle(
                              fontSize: 9.5, color: _inkSoft, lineSpacing: 4)),
                      if (t.evidence.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        pw.Text('依据：${t.evidence}',
                            style: const pw.TextStyle(
                                fontSize: 8.5, color: _inkSoft)),
                      ],
                    ],
                  ),
                )),
          ],
          if (persona.patterns.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _subHeading('反复出现的手感'),
            ...persona.patterns.map((p) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('${p.trigger} → ${p.response}',
                          style: pw.TextStyle(fontSize: 10.5, color: _ink)),
                      if (p.note.isNotEmpty)
                        pw.Text(p.note,
                            style: const pw.TextStyle(
                                fontSize: 9, color: _inkSoft, lineSpacing: 3.5)),
                    ],
                  ),
                )),
          ],
          if (persona.tensions.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _subHeading('同时成立的两件事'),
            ...persona.tensions.map((t) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(t.between,
                          style: pw.TextStyle(fontSize: 10.5, color: _ink)),
                      if (t.detail.isNotEmpty)
                        pw.Text(t.detail,
                            style: const pw.TextStyle(
                                fontSize: 9, color: _inkSoft, lineSpacing: 3.5)),
                    ],
                  ),
                )),
          ],
          if (persona.blindSpots.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _subHeading('你可能没留意的'),
            ...persona.blindSpots.map((s) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('· ',
                          style: pw.TextStyle(fontSize: 10, color: _amber)),
                      pw.Expanded(
                        child: pw.Text(s,
                            style: const pw.TextStyle(
                                fontSize: 9.5, color: _ink, lineSpacing: 4)),
                      ),
                    ],
                  ),
                )),
          ],
          if (persona.openQuestion.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              '还没弄明白的一件事：${persona.openQuestion}',
              style: const pw.TextStyle(
                  fontSize: 9.5, color: _inkSoft, lineSpacing: 4),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _subHeading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 12.5, color: _amber, letterSpacing: 1.5),
        ),
      );

  // --- 洞察 ---------------------------------------------------------------

  static void _addInsightsSection({
    required pw.Document doc,
    required PdfPageFormat format,
    required List<Insight> insights,
  }) {
    final sorted = [...insights]..sort((a, b) => b.dateKey.compareTo(a.dateKey));
    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.fromLTRB(48, 54, 48, 52),
        build: (ctx) => [
          pw.SizedBox(height: 10),
          pw.Text(
            '沿途看出的',
            style: pw.TextStyle(fontSize: 18, color: _ink, letterSpacing: 3),
          ),
          pw.SizedBox(height: 16),
          ...sorted.take(60).map((i) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 14),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      i.dateKey,
                      style: const pw.TextStyle(fontSize: 8, color: _inkSoft),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(i.title,
                        style: pw.TextStyle(fontSize: 11, color: _ink)),
                    pw.SizedBox(height: 3),
                    pw.Text(i.body,
                        style: const pw.TextStyle(
                            fontSize: 9.5, color: _ink, lineSpacing: 4)),
                    if (i.quote != null && i.quote!.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text('「${i.quote}」',
                          style: const pw.TextStyle(
                              fontSize: 9, color: _inkSoft)),
                    ],
                  ],
                ),
              )),
        ],
      ),
    );
  }

  static void _addColophon({
    required pw.Document doc,
    required PdfPageFormat format,
  }) {
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Container(
          color: _paper,
          alignment: pw.Alignment.center,
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                '年 轮',
                style: pw.TextStyle(
                    fontSize: 16, color: _inkSoft, letterSpacing: 6),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                '字都是你自己写的，只是有人替你记得。',
                style: const pw.TextStyle(fontSize: 9.5, color: _inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
