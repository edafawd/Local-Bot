import 'package:flutter/material.dart';
import 'models/chat_message.dart';
import 'models/conversation.dart';
import 'services/ollama_service.dart';

class AppState extends ChangeNotifier {
  final OllamaService ollama = OllamaService();

  List<Conversation> conversations = [];
  Conversation? activeConversation;
  List<String> models = [];
  String selectedModel = '';
  String systemPrompt = 'You are a helpful assistant.';
  bool ollamaOnline = false;
  bool isStreaming = false;

  AppState() { _init(); }

  Future<void> _init() async {
    await checkStatus();
    await loadModels();
    newConversation();
  }

  Future<void> checkStatus() async {
    ollamaOnline = await ollama.isRunning();
    notifyListeners();
  }

  Future<void> loadModels() async {
    models = await ollama.listModels();
    if (models.isNotEmpty && selectedModel.isEmpty) selectedModel = models.first;
    notifyListeners();
  }

  void newConversation() {
    final conv = Conversation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'New Chat',
    );
    conversations.insert(0, conv);
    activeConversation = conv;
    notifyListeners();
  }

  void selectConversation(Conversation conv) {
    activeConversation = conv;
    notifyListeners();
  }

  void deleteConversation(Conversation conv) {
    conversations.remove(conv);
    if (activeConversation == conv) {
      if (conversations.isEmpty) newConversation();
      else activeConversation = conversations.first;
    }
    notifyListeners();
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty || selectedModel.isEmpty || isStreaming) return;
    final conv = activeConversation!;
    if (conv.messages.isEmpty) {
      conv.title = content.length > 30 ? '${content.substring(0, 30)}...' : content;
    }
    conv.messages.add(ChatMessage(role: 'user', content: content));
    final assistantMsg = ChatMessage(role: 'assistant', content: '', isStreaming: true);
    conv.messages.add(assistantMsg);
    isStreaming = true;
    notifyListeners();
    final history = conv.messages
        .where((m) => !m.isStreaming)
        .map((m) => m.toJson())
        .toList();
    await for (final token in ollama.chat(
      model: selectedModel,
      messages: history,
      systemPrompt: systemPrompt,
    )) {
      assistantMsg.content += token;
      notifyListeners();
    }
    assistantMsg.isStreaming = false;
    isStreaming = false;
    notifyListeners();
  }
}
