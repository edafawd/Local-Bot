class ChatMessage {
  final String role;
  String content;
  final DateTime timestamp;
  bool isStreaming;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isStreaming = false,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
  };
}
