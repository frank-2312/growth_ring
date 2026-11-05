import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/fmt.dart';
import '../../core/theme.dart';
import '../../data/models/persona.dart';
import '../../llm/persona_engine.dart';
import '../../shared/widgets/common.dart';
import '../../state/app_state.dart';

class PersonaPage extends StatefulWidget {
  const PersonaPage({super.key});

  @override
  State<PersonaPage> createState() => _PersonaPageState();
}

class _PersonaPageState extends State<PersonaPage> {
  Future<void> _reflect() async {
    final state = context.read<AppState>();
    if (!state.isConfigured) {
      _toast('先去设置里把模型配好，它才能开始读你的字。');
      return;
    }
    final result = await state.reflectNow();
    if (!mounted) return;
    if (result == null) {
      _toast(state.lastError ?? '这次没读成，稍后再试。');
      return;
    }
    _showReflectResult(result);
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _showReflectResult(ReflectResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scroll) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).cardTheme.color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 30),
            children: [
              Center(
                child: Container(
                  width: 34,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '读完了 ${result.digested} 篇'
                '${result.remaining > 0 ? '，还有 ${result.remaining} 篇没读' : ''}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 18),
              if (result.changes.isNotEmpty) ...[
                const SectionLabel('这次的改动'),
                ...result.changes.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        c,
                        style: const TextStyle(fontSize: 13, height: 1.7),
                      ),
                    )),
                const SizedBox(height: 16),
              ],
              if (result.insights.isNotEmpty) ...[
                const SectionLabel('看出来的事'),
                ...result.insights.map((i) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i.title,
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            i.body,
                            style: const TextStyle(fontSize: 12.5, height: 1.75),
                          ),
                          if (i.quote != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              '「${i.quote}」',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontStyle: FontStyle.italic,
                                color: Theme.of(ctx).textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )),
              ],
              if (result.changes.isEmpty && result.insights.isEmpty)
                const Text(
                  '没有明显的新发现。有时候没有变化，也是一种信息。',
                  style: TextStyle(fontSize: 13, height: 1.7),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _retrospective() async {
    final state = context.read<AppState>();
    if (!state.isConfigured) {
      _toast('先去设置里把模型配好。');
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final text = await state.generateRetrospective(days: 30);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (!mounted) return;
      _showText('这一个月的形状', text);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      if (!mounted) return;
      _toast(e.toString());
    }
  }

  void _showText(String title, String body) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Text(
              body,
              style: const TextStyle(
                fontFamily: kBodyFontFamily,
                fontSize: 14.5,
                height: 2.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final persona = state.persona;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soft = isDark ? RingPalette.nightInkSoft : RingPalette.paperInkSoft;
    final accent = isDark ? RingPalette.nightAmber : RingPalette.paperAmber;

    if (persona.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: state.writtenDays == 0
              ? const EmptyHint(
                  icon: Icons.fingerprint,
                  title: '它还不认识你',
                  body: '先写几篇日记，再让它读。\n了解这件事没有捷径，只能一天一天攒。',
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    EmptyHint(
                      icon: Icons.auto_awesome_outlined,
                      title: '有 ${state.writtenDays} 篇等着被读',
                      body: state.isConfigured
                          ? '它还没有开始读。点下面的按钮，让它认真看一遍。\n第一批读完之后，画像就会立起来。'
                          : '还没配置模型。先去设置里填好接口和密钥。',
                      action: state.isConfigured
                          ? FilledButton.icon(
                              onPressed: state.reflecting ? null : _reflect,
                              icon: state.reflecting
                                  ? const SizedBox(
                                      width: 13,
                                      height: 13,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 1.6),
                                    )
                                  : const Icon(Icons.auto_awesome, size: 16),
                              label: Text(state.reflecting
                                  ? (state.reflectStage.isEmpty
                                      ? '正在读…'
                                      : state.reflectStage)
                                  : '读一读'),
                            )
                          : null,
                    ),
                  ],
                ),
        ),
      );
    }

    final completeness = PersonaEngine.completeness(persona.entriesCovered);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 40),
          children: [
            // --- 头部 ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CompletenessRing(
                  value: completeness,
                  size: 62,
                  label: '已读',
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '画像',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '第 ${persona.version} 版 · 读过 ${persona.entriesCovered} 篇'
                        '${state.pendingCount > 0 ? ' · ${state.pendingCount} 篇未读' : ''}',
                        style: TextStyle(fontSize: 11.5, color: soft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- 速写 ---
            Text(
              persona.summary,
              style: const TextStyle(
                fontFamily: kBodyFontFamily,
                fontSize: 17,
                height: 2.0,
                letterSpacing: 0.3,
              ),
            ),
            if (persona.motto.isNotEmpty) ...[
              const SizedBox(height: 12),
              QuietQuote(text: '「${persona.motto}」', label: '你自己的话'),
            ],

            const SizedBox(height: 26),
            _ActionRow(state: state, onReflect: _reflect, onRetro: _retrospective),

            // --- 特质 ---
            if (persona.traits.isNotEmpty) ...[
              const SizedBox(height: 30),
              const SectionLabel('性格里的几处'),
              ...persona.traits.map((t) => _TraitTile(trait: t)),
            ],

            // --- 盲点（最有价值，往前放） ---
            if (persona.blindSpots.isNotEmpty) ...[
              const SizedBox(height: 26),
              SectionLabel(
                '你可能没留意的',
                trailing: Icon(Icons.visibility_outlined,
                    size: 13, color: accent.withValues(alpha: 0.7)),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...persona.blindSpots.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 6, right: 8),
                                child: Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  s,
                                  style: const TextStyle(
                                      fontSize: 13, height: 1.8),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ],

            // --- 矛盾 ---
            if (persona.tensions.isNotEmpty) ...[
              const SizedBox(height: 26),
              const SectionLabel('同时成立的两件事'),
              ...persona.tensions.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.between,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                        if (t.detail.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            t.detail,
                            style: TextStyle(
                                fontSize: 12.5, height: 1.75, color: soft),
                          ),
                        ],
                      ],
                    ),
                  )),
            ],

            // --- 模式 ---
            if (persona.patterns.isNotEmpty) ...[
              const SizedBox(height: 22),
              const SectionLabel('反复出现的手感'),
              ...persona.patterns.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style.copyWith(
                                  fontSize: 13,
                                  height: 1.7,
                                ),
                            children: [
                              TextSpan(
                                text: p.trigger,
                                style: TextStyle(color: soft),
                              ),
                              const TextSpan(text: '  →  '),
                              TextSpan(
                                text: p.response,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        if (p.note.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            p.note,
                            style: TextStyle(
                                fontSize: 12, height: 1.7, color: soft),
                          ),
                        ],
                      ],
                    ),
                  )),
            ],

            // --- 主题 ---
            if (persona.themes.isNotEmpty) ...[
              const SizedBox(height: 22),
              const SectionLabel('占位置的事'),
              ...persona.themes.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 88,
                          child: Text(
                            t.name,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: t.weight / 100,
                                  minHeight: 3,
                                  backgroundColor:
                                      Theme.of(context).dividerColor,
                                  valueColor: AlwaysStoppedAnimation(
                                    accent.withValues(alpha: 0.65),
                                  ),
                                ),
                              ),
                              if (t.note.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(
                                  t.note,
                                  style: TextStyle(
                                      fontSize: 11.5, height: 1.65, color: soft),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
            ],

            // --- 人 ---
            if (persona.people.isNotEmpty) ...[
              const SizedBox(height: 22),
              const SectionLabel('出现过的人'),
              ...persona.people.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            p.name.isEmpty ? '?' : p.name.substring(0, 1),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${p.name} · ${p.role}',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                p.dynamic,
                                style: TextStyle(
                                    fontSize: 12, height: 1.7, color: soft),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
            ],

            // --- 生长 ---
            if (persona.growthEdges.isNotEmpty) ...[
              const SizedBox(height: 22),
              const SectionLabel('正在长出来的'),
              ...persona.growthEdges.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.north_east,
                            size: 12, color: accent.withValues(alpha: 0.7)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s,
                            style: const TextStyle(fontSize: 13, height: 1.75),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],

            if (persona.openQuestion.isNotEmpty) ...[
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '还没弄明白的一件事',
                      style: TextStyle(
                          fontSize: 10.5, letterSpacing: 1.6, color: soft),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      persona.openQuestion,
                      style: const TextStyle(
                        fontFamily: kBodyFontFamily,
                        fontSize: 14,
                        height: 1.95,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 26),
            Center(
              child: Text(
                '以上都是可以被推翻的猜测，不是结论。\n最后更新 ${Fmt.relative(persona.updatedAt)}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, height: 1.7, color: soft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.state,
    required this.onReflect,
    required this.onRetro,
  });

  final AppState state;
  final VoidCallback onReflect;
  final VoidCallback onRetro;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? RingPalette.nightAmber : RingPalette.paperAmber;

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: state.reflecting ? null : onReflect,
            icon: state.reflecting
                ? const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 1.6),
                  )
                : const Icon(Icons.auto_awesome, size: 15),
            label: Text(
              state.reflecting
                  ? (state.reflectStage.isEmpty ? '正在读…' : state.reflectStage)
                  : (state.pendingCount > 0
                      ? '读一读（${state.pendingCount} 篇新）'
                      : '再读一遍'),
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton(
          onPressed: state.reflecting ? null : onRetro,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            textStyle: const TextStyle(fontSize: 12.5),
          ),
          child: Text('回望', style: TextStyle(color: accent)),
        ),
      ],
    );
  }
}

class _TraitTile extends StatelessWidget {
  const _TraitTile({required this.trait});

  final PersonaTrait trait;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soft = isDark ? RingPalette.nightInkSoft : RingPalette.paperInkSoft;
    final accent = isDark ? RingPalette.nightAmber : RingPalette.paperAmber;

    final trendColor = switch (trait.trend) {
      '变强' => isDark ? RingPalette.nightMoss : RingPalette.paperMoss,
      '变弱' => const Color(0xFFB06A4E),
      '新出现' => accent,
      _ => soft,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  trait.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ),
              if (trait.trend.isNotEmpty && trait.trend != '稳定')
                Text(
                  trait.trend,
                  style: TextStyle(fontSize: 10, color: trendColor),
                ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: trait.strength / 100,
              minHeight: 2.5,
              backgroundColor: Theme.of(context).dividerColor,
              valueColor: AlwaysStoppedAnimation(accent.withValues(alpha: 0.7)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            trait.detail,
            style: const TextStyle(fontSize: 12.5, height: 1.8),
          ),
          if (trait.evidence.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '依据：${trait.evidence}',
              style: TextStyle(
                fontSize: 11,
                height: 1.65,
                color: soft.withValues(alpha: 0.9),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
