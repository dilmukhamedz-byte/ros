class ChatMessage {
  final String role; // 'user' | 'assistant'
  String content;
  final DateTime time;
  ChatMessage(this.role, this.content, [DateTime? time]) : time = time ?? DateTime.now();

  bool get isUser => role == 'user';

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        j['role'], j['content'], DateTime.parse(j['created_at']).toLocal());
}

class Conversation {
  final String id, title, role;
  final DateTime createdAt;
  Conversation(this.id, this.title, this.role, this.createdAt);

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        j['id'], j['title'], j['role'], DateTime.parse(j['created_at']).toLocal());
}
