import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/updater.dart';

/// 有新版本时的弹窗。下载过程就在弹窗里走完，下完直接交给系统安装器。
///
/// 强制更新时不能点外面关掉，也没有「稍后」；其余情况保持克制——
/// 用户可以走开，下次启动再说。
class UpdatePrompt extends StatefulWidget {
  const UpdatePrompt({
    super.key,
    required this.info,
    required this.mandatory,
  });

  final UpdateInfo info;
  final bool mandatory;

  static Future<void> show(
    BuildContext context,
    UpdateInfo info, {
    bool mandatory = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !mandatory,
      builder: (_) => UpdatePrompt(info: info, mandatory: mandatory),
    );
  }

  @override
  State<UpdatePrompt> createState() => _UpdatePromptState();
}

enum _Phase { idle, downloading, launching, error, cancelled }

class _UpdatePromptState extends State<UpdatePrompt> {
  _Phase _phase = _Phase.idle;
  int _received = 0;
  int? _total;
  String? _error;
  bool _cancelled = false;

  double? get _fraction {
    final total = _total;
    if (total == null || total <= 0) return null;
    return (_received / total).clamp(0.0, 1.0);
  }

  Future<void> _start() async {
    setState(() {
      _phase = _Phase.downloading;
      _received = 0;
      _total = null;
      _error = null;
      _cancelled = false;
    });

    try {
      final file = await Updater.download(
        widget.info,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _received = received;
            _total = total ?? _total;
          });
        },
        isCancelled: () => _cancelled,
      );
      if (!mounted) return;
      setState(() => _phase = _Phase.launching);

      final err = await Updater.install(file);
      if (!mounted) return;
      if (err == null) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _phase = _Phase.error;
          _error = err;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (isCancelledError(e)) {
          _phase = _Phase.cancelled;
        } else {
          _phase = _Phase.error;
          _error = '$e';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soft = isDark ? RingPalette.nightInkSoft : RingPalette.paperInkSoft;
    final accent = isDark ? RingPalette.nightAmber : RingPalette.paperAmber;

    return AlertDialog(
      title: Text(
        widget.mandatory ? '需要更新后才能继续' : '有新的一版',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      content: SingleChildScrollView(child: _content(soft, accent)),
      actions: _actions(soft),
    );
  }

  Widget _content(Color soft, Color accent) {
    switch (_phase) {
      case _Phase.idle:
      case _Phase.cancelled:
      case _Phase.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'v${widget.info.version}'
              '${widget.info.publishedAt.isEmpty ? '' : ' · ${widget.info.publishedAt}'}',
              style: TextStyle(fontSize: 11.5, color: soft, letterSpacing: 0.6),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Text(
                  widget.info.notes.isEmpty
                      ? '修了一些问题，也调整了几处细节。'
                      : widget.info.notes,
                  style: const TextStyle(fontSize: 13.5, height: 1.75),
                ),
              ),
            ),
            if (_phase == _Phase.cancelled) ...[
              const SizedBox(height: 14),
              Text('下载已取消。', style: TextStyle(fontSize: 11.5, color: soft)),
            ],
            if (_phase == _Phase.error) ...[
              const SizedBox(height: 14),
              Text(
                _error ?? '下载失败',
                style: TextStyle(fontSize: 11.5, height: 1.6, color: accent),
              ),
              const SizedBox(height: 6),
              Text(
                '如果提示没有安装权限，去系统设置里允许「安装未知应用」再试。',
                style: TextStyle(fontSize: 11, height: 1.6, color: soft),
              ),
            ],
            if (widget.mandatory) ...[
              const SizedBox(height: 12),
              Text(
                '这个版本太旧了，继续用会出现问题。',
                style: TextStyle(fontSize: 11.5, color: soft),
              ),
            ],
          ],
        );

      case _Phase.downloading:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('正在下载 v${widget.info.version}', style: const TextStyle(fontSize: 13.5)),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: _fraction,
                minHeight: 4,
                backgroundColor: Theme.of(context).dividerColor,
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _fraction == null
                  ? _fmtBytes(_received)
                  : '${(_fraction! * 100).round()}% · ${_fmtBytes(_received)}'
                      '${_total == null ? '' : ' / ${_fmtBytes(_total!)}'}',
              style: TextStyle(fontSize: 11, color: soft),
            ),
          ],
        );

      case _Phase.launching:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('正在唤起安装器…', style: TextStyle(fontSize: 13.5)),
        );
    }
  }

  List<Widget> _actions(Color soft) {
    if (_phase == _Phase.downloading) {
      return [
        TextButton(
          onPressed: () => setState(() => _cancelled = true),
          style: TextButton.styleFrom(foregroundColor: soft),
          child: const Text('取消'),
        ),
      ];
    }

    if (_phase == _Phase.launching) {
      return const [SizedBox.shrink()];
    }

    return [
      if (!widget.mandatory)
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: soft),
          child: const Text('稍后'),
        ),
      FilledButton(
        onPressed: _start,
        child: Text(_phase == _Phase.error ? '重试' : '下载并安装'),
      ),
    ];
  }
}

String _fmtBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
