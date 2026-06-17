import 'chat_message.dart';

class Conversation {
  final String id;
  String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;

  Conversation({
    required this.id,
    required this.title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
  })  : messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now();
}
