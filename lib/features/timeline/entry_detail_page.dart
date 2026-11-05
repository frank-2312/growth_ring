import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/fmt.dart';
import '../../core/theme.dart';
import '../../data/models/diary_entry.dart';
import '../../shared/widgets/common.dart';
import '../../state/app_state.dart';

class EntryDetailPage extends StatefulWidget {
  const EntryDetailPage({super.key, required this.entry});

  final DiaryEntry entry;

  @override
  State<EntryDetailPage> createState() => _EntryDetailPageState();
}

class _EntryDetailPageState extends State<EntryDetailPage> {
  late final TextEditingController _controller;
  late DiaryEntry _entry;
  bool _editing = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _controller = TextEditingController(text: _entry.content)
      ..addListener(() {
        final changed = _controller.text != _entry.content;
        if (changed != _dirty) setState(() => _dirty = changed);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final updated = _entry.copyWith(content: _controller.text);
    await state.saveEntry(
      dateKey: _entry.dateKey,
      content: _controller.text,
      mood: _entry.mood,
      energy: _entry.energy,
    );
    if (!mounted) return;
    setState(() {
      _entry = updated;
      _editing = false;
      _dirty = false;
    });
    if (state.isConfigured) {
      unawaited(state.requestEcho(updated));
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删掉 ${Fmt.monthDay(_entry.date)} 这篇？'),
        content: const Text('删了就找不回来了。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('算了')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AppState>().deleteEntry(_entry.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soft = isDark ? RingPalette.nightInkSoft : RingPalette.paperInkSoft;
    final accent = isDark ? RingPalette.nightAmber : RingPalette.paperAmber;

    return Scaffold(
      appBar: AppBar(
        title: Text(Fmt.monthDay(_entry.date)),
        actions: [
          if (_editing)
            TextButton(
              onPressed: _dirty ? _save : null,
              child: const Text('保存'),
            )
          else
            IconButton(
              tooltip: '编辑',
              onPressed: () => setState(() => _editing = true),
              icon: const Icon(Icons.edit_outlined, size: 19),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, size: 20),
            onSelected: (v) {
              if (v == 'delete') _delete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('删除这篇')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
        children: [
          Row(
            children: [
              Text(Fmt.weekday(_entry.date),
                  style: TextStyle(fontSize: 12, color: soft)),
              const SizedBox(width: 10),
              if (_entry.mood != null) TagPill(_entry.mood!, highlight: true),
              const SizedBox(width: 8),
              Text(
                '${Fmt.wordCount(_controller.text)} 字',
                style: TextStyle(fontSize: 11, color: soft),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_editing)
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: null,
              minLines: 12,
              style: const TextStyle(
                fontFamily: kBodyFontFamily,
                fontSize: 16.5,
                height: 1.95,
              ),
              decoration: const InputDecoration(
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            )
          else
            Text(
              _entry.content,
              style: const TextStyle(
                fontFamily: kBodyFontFamily,
                fontSize: 16,
                height: 1.95,
              ),
            ),
          if (_entry.echo != null && _entry.echo!.isNotEmpty) ...[
            const SizedBox(height: 26),
            SectionLabel('它说', trailing: Icon(Icons.auto_awesome,
                size: 13, color: accent.withValues(alpha: 0.8))),
            QuietQuote(text: _entry.echo!),
          ],
        ],
      ),
    );
  }
}
