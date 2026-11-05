import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/fmt.dart';
import '../../core/theme.dart';
import '../../data/models/chat_message.dart';
import '../../state/app_state.dart';

const _starters = [
  '你觉得我是个什么样的人？',
  '我最近在反复纠结什么？',
  '这两个月我有什么变化？',
  '有没有什么事我一直没敢承认？',
];

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  int _lastCount = 0;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (animated) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty) return;
    _input.clear();
    final state = context.read<AppState>();
    _lastCount = state.chatMessages.length;
    await state.sendMessage(text);
    if (mounted) _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final messages = state.chatMessages;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soft = isDark ? RingPalette.nightInkSoft : RingPalette.paperInkSoft;

    if (messages.length != _lastCount) {
      _lastCount = messages.length;
      _scrollToEnd();
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '知己',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          state.persona.isEmpty
                              ? '它还没读过你的日记'
                              : '读过 ${state.persona.entriesCovered} 篇 · 记得你说过的话',
                          style: TextStyle(fontSize: 12, color: soft),
                        ),
                      ],
                    ),
                  ),
                  if (messages.isNotEmpty)
                    IconButton(
                      tooltip: '清空对话',
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('清空这段对话？'),
                            content: const Text('它对你日记的记忆不会受影响。'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('算了')),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.redAccent),
                                child: const Text('清空'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true && context.mounted) {
                          await context.read<AppState>().clearChat();
                        }
                      },
                      icon: const Icon(Icons.more_horiz, size: 20),
                    ),
                ],
              ),
            ),
            Expanded(
              child: messages.isEmpty
                  ? _EmptyChat(onPick: _send)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                      itemCount: messages.length,
                      itemBuilder: (context, i) => _Bubble(
                        message: messages[i],
                        showTime: i == 0 ||
                            messages[i]
                                    .createdAt
                                    .difference(messages[i - 1].createdAt)
                                    .inMinutes >
                                10,
                      ),
                    ),
            ),
            _inputBar(state),
          ],
        ),
      ),
    );
  }

  Widget _inputBar(AppState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? RingPalette.nightAmber : RingPalette.paperAmber;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              enabled: !state.chatting,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: const TextStyle(fontSize: 14.5, height: 1.6),
              decoration: InputDecoration(
                hintText: state.chatting ? '它正在想…' : '说点什么',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: state.chatting ? null : () => _send(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: state.chatting
                    ? accent.withValues(alpha: 0.3)
                    : accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: state.chatting
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Icon(
                      Icons.arrow_upward,
                      size: 19,
                      color: isDark ? const Color(0xFF1A1712) : Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.onPick});

  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soft = isDark ? RingPalette.nightInkSoft : RingPalette.paperInkSoft;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 60, 28, 20),
      children: [
        Icon(Icons.forum_outlined,
            size: 30, color: soft.withValues(alpha: 0.45)),
        const SizedBox(height: 18),
        Text(
          '它读过你写的东西，所以你可以问得直接一点。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, height: 1.8, color: soft),
        ),
        const SizedBox(height: 28),
        ..._starters.map((q) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onPick(q),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Text(
                    q,
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
              ),
            )),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.showTime});

  final ChatMessage message;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soft = isDark ? RingPalette.nightInkSoft : RingPalette.paperInkSoft;
    final accent = isDark ? RingPalette.nightAmber : RingPalette.paperAmber;
    final fromUser = message.fromUser;

    return Padding(
      padding: EdgeInsets.only(top: showTime ? 18 : 8),
      child: Column(
        crossAxisAlignment:
            fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showTime)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                Fmt.clock(message.createdAt),
                style: TextStyle(
                    fontSize: 9.5, color: soft.withValues(alpha: 0.7)),
              ),
            ),
          if (fromUser)
            Container(
              constraints: const BoxConstraints(maxWidth: 280),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Text(
                message.text,
                style: const TextStyle(fontSize: 14, height: 1.7),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text.isEmpty && message.streaming ? '…' : message.text,
                    style: TextStyle(
                      fontFamily: kBodyFontFamily,
                      fontSize: 15,
                      height: 1.9,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  if (message.streaming)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
