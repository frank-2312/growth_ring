import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/analytics.dart';
import '../../core/theme.dart';
import '../../data/models/diary_entry.dart';
import '../../services/pdf_exporter.dart';
import '../../shared/widgets/common.dart';
import '../../state/app_state.dart';

enum _Range { all, d30, d90, thisYear }

class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  ExportOptions _options = const ExportOptions();
  _Range _range = _Range.all;
  bool _building = false;

  Set<String>? _dateKeysFor(List<DiaryEntry> entries) {
    if (_range == _Range.all) return null;
    final now = DateTime.now();
    final cutoff = switch (_range) {
      _Range.d30 => now.subtract(const Duration(days: 30)),
      _Range.d90 => now.subtract(const Duration(days: 90)),
      _Range.thisYear => DateTime(now.year, 1, 1),
      _Range.all => DateTime(2000),
    };
    return entries
        .where((e) => e.date.isAfter(cutoff))
        .map((e) => e.dateKey)
        .toSet();
  }

  Future<void> _preview() async {
    final state = context.read<AppState>();
    final entries = state.entries;
    if (entries.isEmpty) return;

    setState(() => _building = true);
    try {
      final opts = _options.copyWith(onlyDateKeys: _dateKeysFor(entries));
      final bytes = await PdfExporter.build(
        entries: entries,
        persona: state.persona,
        insights: state.insights,
        nickname: state.settings.nickname,
        options: opts,
      );
      Analytics.track('pdf_exported', {
        'entries': Analytics.countBucket(entries.length),
      });
      if (!mounted) return;
      setState(() => _building = false);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _PreviewPage(bytes: bytes),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _building = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soft = isDark ? RingPalette.nightInkSoft : RingPalette.paperInkSoft;
    final total = state.entries.where((e) => !e.isEmpty).length;

    return Scaffold(
      appBar: AppBar(title: const Text('导出 PDF')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.menu_book_outlined, size: 22, color: soft),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '会排成一本可以打印的小书：封面、按月的正文、'
                    '${_options.includePersona ? '一份画像、' : ''}'
                    '${_options.includeInsights ? '一份洞察、' : ''}'
                    '以及一句后记。',
                    style: TextStyle(fontSize: 12, height: 1.75, color: soft),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),

          const SectionLabel('范围'),
          Text(
            '共 $total 篇可选',
            style: TextStyle(fontSize: 11.5, color: soft),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _choice('全部', _Range.all),
              _choice('最近 30 天', _Range.d30),
              _choice('最近 90 天', _Range.d90),
              _choice('今年', _Range.thisYear),
            ],
          ),

          const SizedBox(height: 28),
          const SectionLabel('纸张'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              _paperChoice('A5 小书', ExportPaper.a5),
              _paperChoice('A4 打印', ExportPaper.a4),
            ],
          ),

          const SizedBox(height: 28),
          const SectionLabel('包含'),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('「它眼中的你」', style: TextStyle(fontSize: 14)),
            subtitle: Text('附上当前画像全文',
                style: TextStyle(fontSize: 11, color: soft)),
            value: _options.includePersona,
            onChanged: (v) =>
                setState(() => _options = _options.copyWith(includePersona: v)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('沿途看出的洞察', style: TextStyle(fontSize: 14)),
            subtitle: Text('附上洞察时间线',
                style: TextStyle(fontSize: 11, color: soft)),
            value: _options.includeInsights,
            onChanged: (v) =>
                setState(() => _options = _options.copyWith(includeInsights: v)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('每篇下面的一句话', style: TextStyle(fontSize: 14)),
            subtitle: Text('当天写完后它留的回声',
                style: TextStyle(fontSize: 11, color: soft)),
            value: _options.includeEcho,
            onChanged: (v) =>
                setState(() => _options = _options.copyWith(includeEcho: v)),
          ),

          const SizedBox(height: 30),
          FilledButton.icon(
            onPressed: _building || total == 0 ? null : _preview,
            icon: _building
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.8, valueColor: AlwaysStoppedAnimation(Colors.white)),
                  )
                : const Icon(Icons.visibility_outlined, size: 17),
            label: Text(_building ? '正在排版…' : '生成并预览'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '预览页里可以「保存到手机」或直接用系统打印。'
            'PDF 里以图片/文字形式包含了你的日记原文，分享前注意场合。',
            style: TextStyle(fontSize: 10.5, height: 1.7, color: soft),
          ),
        ],
      ),
    );
  }

  Widget _choice(String label, _Range value) {
    final active = _range == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? RingPalette.nightAmber : RingPalette.paperAmber;
    return GestureDetector(
      onTap: () => setState(() => _range = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? accent.withValues(alpha: 0.55)
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: active ? accent : null,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _paperChoice(String label, ExportPaper value) {
    final active = _options.paper == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? RingPalette.nightAmber : RingPalette.paperAmber;
    return GestureDetector(
      onTap: () => setState(() => _options = _options.copyWith(paper: value)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? accent.withValues(alpha: 0.55)
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: active ? accent : null,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _PreviewPage extends StatelessWidget {
  const _PreviewPage({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final stamp = DateTime.now();
    final name = '年轮-日记-${stamp.year}'
        '${stamp.month.toString().padLeft(2, '0')}'
        '${stamp.day.toString().padLeft(2, '0')}.pdf';

    return Scaffold(
      appBar: AppBar(title: const Text('预览')),
      body: PdfPreview(
        build: (_) async => bytes,
        pdfFileName: name,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        useActions: true,
        padding: const EdgeInsets.all(8),
      ),
    );
  }
}
