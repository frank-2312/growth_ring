import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/fmt.dart';
import '../../core/theme.dart';
import '../../shared/widgets/common.dart';
import '../../state/app_state.dart';
import '../settings/settings_page.dart';

const _moods = ['平静', '轻快', '开阔', '发闷', '烦躁', '疲惫', '说不清'];

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  /// 缓存宿主引用：dispose 里还要兜底保存，那时 context 已经不能用了
  late final AppState _state;

  Timer? _saveDebounce;
  final _dateKey = Fmt.dateKey(DateTime.now());
  String _lastSaved = '';
  DateTime? _savedAt;
  String? _mood;
  int? _energy;
  bool _echoLoading = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _state = context.read<AppState>();
    final entry = _state.todayEntry;
    if (entry != null) {
      _controller.text = entry.content;
      _lastSaved = entry.content;
      _mood = entry.mood;
      _energy = entry.energy;
    }
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    // 离开时兜底保存一次
    final text = _controller.text;
    if (text.trim().isNotEmpty && text != _lastSaved) {
      unawaited(_persist(text));
    }
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() => _dirty = _controller.text != _lastSaved);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 1400), () {
      final text = _controller.text;
      if (text.trim().isEmpty || text == _lastSaved) return;
      unawaited(_persist(text));
    });
  }

  Future<void> _persist(String text) async {
    final state = _state;
    await state.saveEntry(
      dateKey: _dateKey,
      content: text,
      mood: _mood,
      energy: _energy,
    );
    if (!mounted) return;
    setState(() {
      _lastSaved = text;
      _savedAt = DateTime.now();
      _dirty = false;
    });
  }

  Future<void> _askEcho() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    setState(() => _echoLoading = true);
    final state = _state;
    final entry = await state.saveEntry(
      dateKey: _dateKey,
      content: text,
      mood: _mood,
      energy: _energy,
    );
    _lastSaved = text;
    _savedAt = DateTime.now();
    await state.requestEcho(entry);
    if (!mounted) return;
    setState(() => _echoLoading = false);
    if (state.todayEntry?.echo == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('它没能说出话来，可能是模型配置或网络的问题。')),
      );
    }
  }

  void _pickMood(String value) {
    setState(() => _mood = _mood == value ? null : value);
    if (_controller.text.trim().isNotEmpty) {
      unawaited(_persist(_controller.text));
    }
  }

  void _pickEnergy(int value) {
    setState(() => _energy = _energy == value ? null : value);
    if (_controller.text.trim().isNotEmpty) {
      unawaited(_persist(_controller.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final entry = state.todayEntry;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soft = isDark ? RingPalette.nightInkSoft : RingPalette.paperInkSoft;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
          children: [
            _header(state, now, soft),
            const SizedBox(height: 22),
            _editor(soft),
            const SizedBox(height: 18),
            _moodRow(soft),
            const SizedBox(height: 14),
            _energyRow(soft),
            if (entry?.echo != null) ...[
              const SizedBox(height: 24),
              SectionLabel('它说'),
              QuietQuote(text: entry!.echo!),
            ] else if (entry != null && entry.content.trim().isNotEmpty) ...[
              const SizedBox(height: 22),
              _echoPrompt(state),
            ],
            if (state.reflecting) ...[
              const SizedBox(height: 22),
              _reflectingBar(state),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(AppState state, DateTime now, Color soft) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Fmt.fullDate(now),
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    Fmt.weekday(now),
                    style: TextStyle(fontSize: 12.5, color: soft),
                  ),
                  if (state.streak > 1) ...[
                    Text(' · ', style: TextStyle(fontSize: 12.5, color: soft)),
                    Text(
                      '连续 ${state.streak} 天',
                      style: TextStyle(fontSize: 12.5, color: soft),
                    ),
                  ],
                  if (_savedAt != null) ...[
                    Text(' · ', style: TextStyle(fontSize: 12.5, color: soft)),
                    Text(
                      _dirty ? '正在写…' : '已存 ${Fmt.clock(_savedAt!)}',
                      style: TextStyle(fontSize: 12.5, color: soft),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '设置',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          ),
          icon: const Icon(Icons.tune, size: 20),
        ),
      ],
    );
  }

  Widget _editor(Color soft) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      maxLines: null,
      minLines: 10,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(
        fontFamily: kBodyFontFamily,
        fontSize: 16.5,
        height: 1.95,
      ),
      decoration: InputDecoration(
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: '今天发生了什么？\n\n不用写得好，写下来就行。',
        hintStyle: TextStyle(
          fontFamily: kBodyFontFamily,
          fontSize: 16,
          height: 1.95,
          color: soft.withValues(alpha: 0.75),
        ),
      ),
    );
  }

  Widget _moodRow(Color soft) {
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _moods.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final m = _moods[i];
          final active = _mood == m;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final accent = isDark ? RingPalette.nightAmber : RingPalette.paperAmber;
          return GestureDetector(
            onTap: () => _pickMood(m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? accent.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: active
                      ? accent.withValues(alpha: 0.5)
                      : Theme.of(context).dividerColor,
                ),
              ),
              child: Text(
                m,
                style: TextStyle(
                  fontSize: 12,
                  color: active ? accent : soft,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _energyRow(Color soft) {
    return Row(
      children: [
        Text('精力', style: TextStyle(fontSize: 11, color: soft, letterSpacing: 1)),
        const SizedBox(width: 10),
        ...List.generate(5, (i) {
          final level = i + 1;
          final active = (_energy ?? 0) >= level;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final accent = isDark ? RingPalette.nightMoss : RingPalette.paperMoss;
          return GestureDetector(
            onTap: () => _pickEnergy(level),
            child: Container(
              margin: const EdgeInsets.only(right: 7),
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? accent : Colors.transparent,
                border: Border.all(
                  color: active ? accent : Theme.of(context).dividerColor,
                  width: 1.2,
                ),
              ),
            ),
          );
        }),
        if (_energy != null)
          Text(' $_energy/5', style: TextStyle(fontSize: 10.5, color: soft)),
      ],
    );
  }

  Widget _echoPrompt(AppState state) {
    if (!state.isConfigured) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _echoLoading ? null : _askEcho,
        icon: _echoLoading
            ? const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              )
            : const Icon(Icons.auto_awesome, size: 15),
        label: Text(_echoLoading ? '正在读…' : '让它看一眼'),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          textStyle: const TextStyle(fontSize: 12.5),
        ),
      ),
    );
  }

  Widget _reflectingBar(AppState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? RingPalette.nightAmber : RingPalette.paperAmber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.8),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              state.reflectStage.isEmpty ? '正在整理对你的理解…' : state.reflectStage,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
