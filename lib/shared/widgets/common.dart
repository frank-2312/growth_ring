import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// 小节标题：小、字距宽、琥珀色，克制地分隔内容
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? RingPalette.nightAmber : RingPalette.paperAmber;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 0.7, color: Theme.of(context).dividerColor)),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  const EmptyHint({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final soft = Theme.of(context).textTheme.bodySmall?.color;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: soft?.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, height: 1.7, color: soft),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class TagPill extends StatelessWidget {
  const TagPill(this.text, {super.key, this.highlight = false});

  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? RingPalette.nightAmber : RingPalette.paperAmber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlight
            ? accent.withValues(alpha: 0.12)
            : Theme.of(context).dividerColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          color: highlight ? accent : Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
    );
  }
}

/// 一小段「它说的话」，用左侧竖线标出，不用气泡
class QuietQuote extends StatelessWidget {
  const QuietQuote({super.key, required this.text, this.label});

  final String text;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? RingPalette.nightAmber : RingPalette.paperAmber;
    final soft = Theme.of(context).textTheme.bodySmall?.color;
    return Container(
      padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: accent.withValues(alpha: 0.55), width: 1.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: TextStyle(fontSize: 10, letterSpacing: 1.4, color: soft),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.7,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 画像完成度的小环
class CompletenessRing extends StatelessWidget {
  const CompletenessRing({
    super.key,
    required this.value,
    required this.size,
    this.label,
  });

  final double value;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? RingPalette.nightAmber : RingPalette.paperAmber;
    final soft = Theme.of(context).textTheme.bodySmall?.color;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: value.clamp(0.0, 1.0),
              strokeWidth: 2.2,
              backgroundColor: Theme.of(context).dividerColor,
              valueColor: AlwaysStoppedAnimation(accent),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (label != null)
                Text(label!, style: TextStyle(fontSize: 8.5, color: soft)),
            ],
          ),
        ],
      ),
    );
  }
}
