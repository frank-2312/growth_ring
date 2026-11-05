import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models/companion_style.dart';
import '../../shared/widgets/common.dart';
import '../../state/app_state.dart';

/// 调「知己」的脾气。
///
/// 和「画像」页的区别要说清楚：画像里写的是它对你的理解（由日记长出来，你只能读），
/// 这一页写的是它自己的样子（你定，模型照做）。
class CompanionSettingsPage extends StatefulWidget {
  const CompanionSettingsPage({super.key});

  @override
  State<CompanionSettingsPage> createState() => _CompanionSettingsPageState();
}

class _CompanionSettingsPageState extends State<CompanionSettingsPage> {
  late CompanionStyle _base;
  late CompanionStyle _draft;
  late final TextEditingController _name;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _base = context.read<AppState>().settings.companion;
    _draft = _base;
    _name = TextEditingController(text: _base.name);
    _note = TextEditingController(text: _base.note);
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  CompanionStyle get _current =>
      _draft.copyWith(name: _name.text.trim(), note: _note.text.trim());

  bool get _dirty => _current.toJsonString() != _base.toJsonString();

  void _touch(CompanionStyle next) => setState(() => _draft = next);

  Future<void> _save({bool quiet = false}) async {
    final state = context.read<AppState>();
    final next = _current;
    await state.updateSettings(state.settings.copyWith(companion: next));
    if (!mounted) return;
    setState(() {
      _base = next;
      _draft = next;
      _name.text = next.name;
      _note.text = next.note;
    });
    if (!quiet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('存好了。下一条回复起，它就是这个人。')),
      );
    }
  }

  Future<bool> _confirmDiscard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('还没存'),
        content: const Text('刚才调的那些要丢掉吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('继续调'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('丢掉'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soft = isDark ? RingPalette.nightInkSoft : RingPalette.paperInkSoft;
    final accent = isDark ? RingPalette.nightAmber : RingPalette.paperAmber;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('它的样子'),
          actions: [
            TextButton(
              onPressed: _dirty ? _save : null,
              child: const Text('保存'),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(
              '这里调的是它说话的样子，不是它对你的了解。\n'
              '画像由日记长出来，你改不了；但用什么口气说话，你说了算。',
              style: TextStyle(fontSize: 11.5, height: 1.8, color: soft),
            ),

            const SizedBox(height: 28),
            SectionLabel('叫什么'),
            TextField(
              controller: _name,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: '名字',
                hintText: '留空就不特意起名',
              ),
            ),

            const SizedBox(height: 28),
            SectionLabel('你们算什么'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CompanionRelation.values.map((r) {
                final selected = _current.relation == r;
                return ChoiceChip(
                  label: Text(r.label, style: const TextStyle(fontSize: 12)),
                  selected: selected,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: selected ? accent : soft,
                  ),
                  onSelected: (_) => _touch(_current.copyWith(relation: r)),
                );
              }).toList(),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _current.relation.hint,
                style: TextStyle(fontSize: 11, color: soft.withValues(alpha: 0.9)),
              ),
            ),

            const SizedBox(height: 28),
            SectionLabel('脾气'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CompanionPreset.all.map((p) {
                return ActionChip(
                  label: Text(p.label, style: const TextStyle(fontSize: 12)),
                  onPressed: () => _touch(_draft.copyWith(
                    relation: p.style.relation,
                    warmth: p.style.warmth,
                    directness: p.style.directness,
                    talkativeness: p.style.talkativeness,
                    pushback: p.style.pushback,
                    humor: p.style.humor,
                    memory: p.style.memory,
                  )),
                );
              }).toList(),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '选一套再往下微调，比从零拖六个滑杆快。',
                style: TextStyle(fontSize: 11, color: soft.withValues(alpha: 0.9)),
              ),
            ),

            const SizedBox(height: 18),
            ..._dims.map((d) => _ToneSlider(
                  dim: d,
                  value: d.get(_current),
                  onChanged: (v) => _touch(d.set(_current, v)),
                )),

            const SizedBox(height: 22),
            SectionLabel('再交代几句'),
            TextField(
              controller: _note,
              minLines: 3,
              maxLines: 6,
              maxLength: 160,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 13.5, height: 1.7),
              decoration: const InputDecoration(
                hintText: '例如：别老问我问题；可以损我；别提我妈。\n这些会原样交代给它，优先级高于上面的滑杆。',
                hintStyle: TextStyle(fontSize: 12, height: 1.7),
              ),
            ),

            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '它会这样理解自己',
                    style: TextStyle(
                        fontSize: 10.5, letterSpacing: 1.6, color: accent),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _current.toPromptBlock(),
                    style: TextStyle(fontSize: 11, height: 1.75, color: soft),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '调得越极端越容易被模型「演出」成模板：滑杆全推到 100，它就只剩一个脾气了。'
              '60 上下通常最像人。',
              style: TextStyle(fontSize: 11, height: 1.75, color: soft),
            ),
          ],
        ),
      ),
    );
  }
}

/// 一个维度的滑杆定义。用函数取/设值，省掉六个重复 widget。
class _Dim {
  const _Dim({
    required this.title,
    required this.low,
    required this.high,
    required this.levels,
    required this.get,
    required this.set,
  });

  final String title;
  final String low;
  final String high;

  /// 三档口语描述：偏左 / 中间 / 偏右
  final List<String> levels;
  final int Function(CompanionStyle) get;
  final CompanionStyle Function(CompanionStyle, int) set;

  String levelOf(int v) => v < 35 ? levels[0] : (v <= 65 ? levels[1] : levels[2]);
}

final List<_Dim> _dims = [
  _Dim(
    title: '温度',
    low: '冷',
    high: '热',
    levels: const ['不主动安慰', '正常', '亲近但不腻'],
    get: (s) => s.warmth,
    set: (s, v) => s.copyWith(warmth: v),
  ),
  _Dim(
    title: '直白',
    low: '绕着说',
    high: '想到就说',
    levels: const ['留余地', '该说就说', '不给面子'],
    get: (s) => s.directness,
    set: (s, v) => s.copyWith(directness: v),
  ),
  _Dim(
    title: '话量',
    low: '一句',
    high: '絮叨',
    levels: const ['几个字就完', '两三句', '会自己展开'],
    get: (s) => s.talkativeness,
    set: (s, v) => s.copyWith(talkativeness: v),
  ),
  _Dim(
    title: '顶嘴',
    low: '顺着你',
    high: '专挑刺',
    levels: const ['很少反驳', '该顶就顶', '会直接说不对'],
    get: (s) => s.pushback,
    set: (s, v) => s.copyWith(pushback: v),
  ),
  _Dim(
    title: '幽默',
    low: '认真',
    high: '没正形',
    levels: const ['不开玩笑', '偶尔一句', '会自嘲、会损'],
    get: (s) => s.humor,
    set: (s, v) => s.copyWith(humor: v),
  ),
  _Dim(
    title: '提旧事',
    low: '不提',
    high: '常提',
    levels: const ['几乎不提', '偶尔一次', '会主动带出过去'],
    get: (s) => s.memory,
    set: (s, v) => s.copyWith(memory: v),
  ),
];

class _ToneSlider extends StatelessWidget {
  const _ToneSlider({
    required this.dim,
    required this.value,
    required this.onChanged,
  });

  final _Dim dim;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soft = isDark ? RingPalette.nightInkSoft : RingPalette.paperInkSoft;
    final accent = isDark ? RingPalette.nightAmber : RingPalette.paperAmber;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(dim.title, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  dim.levelOf(value),
                  style: TextStyle(fontSize: 10.5, color: accent),
                ),
              ),
              Text('$value', style: TextStyle(fontSize: 10.5, color: soft)),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            onChanged: (v) => onChanged(v.round()),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(dim.low,
                    style: TextStyle(
                        fontSize: 10, color: soft.withValues(alpha: 0.75))),
                Text(dim.high,
                    style: TextStyle(
                        fontSize: 10, color: soft.withValues(alpha: 0.75))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
