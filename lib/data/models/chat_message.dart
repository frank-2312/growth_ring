/// 与「知己」的一条对话。
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.fromUser,
    required this.text,
    required this.createdAt,
    this.streaming = false,
  });

  final String id;
  final bool fromUser;
  final String text;
  final DateTime createdAt;

  /// 流式输出中，界面上显示光标
  final bool streaming;

  ChatMessage copyWith({String? text, bool? streaming}) => ChatMessage(
        id: id,
        fromUser: fromUser,
        text: text ?? this.text,
        createdAt: createdAt,
        streaming: streaming ?? this.streaming,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'from_user': fromUser ? 1 : 0,
        'text': text,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  static ChatMessage fromMap(Map<String, Object?> m) => ChatMessage(
        id: m['id'] as String,
        fromUser: (m['from_user'] as int?) == 1,
        text: (m['text'] as String?) ?? '',
        createdAt:
            DateTime.fromMillisecondsSinceEpoch((m['created_at'] as int?) ?? 0),
      );

  Map<String, String> toApiJson() => {
        'role': fromUser ? 'user' : 'assistant',
        'content': text,
      };
}
