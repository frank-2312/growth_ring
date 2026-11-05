import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/fmt.dart';
import '../../core/theme.dart';
import '../../data/models/diary_entry.dart';
import '../../shared/widgets/common.dart';
import '../../state/app_state.dart';
import '../export/export_page.dart';
import 'entry_detail_page.dart';

class TimelinePage extends StatelessWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soft = isDark ? RingPalette.nightInkSoft : RingPalette.paperInkSoft;

    final entries = state.entries.where((e) => !e.isEmpty).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '时光',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entries.isEmpty
                              ? '还没有留下字'
                              : '${entries.length} 篇 · 连续 ${state.streak} 天 · 共计 ${state.stats.spanDays} 天',
                          style: TextStyle(fontSize: 12, color: soft),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '导出 PDF',
                    onPressed: entries.isEmpty
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const ExportPage()),
                            ),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? const EmptyHint(
                      icon: Icons.auto_stories_outlined,
                      title: '这里还空着',
                      body: '回到「今天」，写下第一条。\n哪怕只有一句，也比空白好。',
                    )
                  : _TimelineList(entries: entries),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({required this.entries});

  final List<DiaryEntry> entries;

  @override
  Widget build(BuildContext context) {
    // 预先把「月份头 + 条目」拍平，避免 builder 里做分组判断
    final rows = <Object>[];
    String? currentMonth;
    for (final e in entries) {
      final month = '${e.date.year} 年 ${e.date.month} 月';
      if (month != currentMonth) {
        currentMonth = month;
        rows.add(month);
      }
      rows.add(e);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        if (row is String) {
          return Padding(
            padding: EdgeInsets.only(top: i == 0 ? 6 : 26, bottom: 10),
            child: SectionLabel(row),
          );
        }
        final entry = row as DiaryEntry;
        return _EntryCard(entry: entry);
      },
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final DiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soft = isDark ? RingPalette.nightInkSoft : RingPalette.paperInkSoft;
    final accent = isDark ? RingPalette.nightAmber : RingPalette.paperAmber;
    final preview = Fmt.ellipsis(entry.content, 90);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EntryDetailPage(entry: entry)),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    Fmt.monthDay(entry.date),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Fmt.weekday(entry.date),
                    style: TextStyle(fontSize: 11, color: soft),
                  ),
                  const Spacer(),
                  if (entry.mood != null) TagPill(entry.mood!),
                  if (entry.mood != null) const SizedBox(width: 6),
                  Text(
                    '${Fmt.wordCount(entry.content)} 字',
                    style: TextStyle(fontSize: 10, color: soft),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kBodyFontFamily,
                  fontSize: 14,
                  height: 1.75,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              if (entry.echo != null && entry.echo!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.subdirectory_arrow_right,
                        size: 12, color: accent.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        entry.echo!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: soft,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
