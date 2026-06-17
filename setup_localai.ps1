# Local AI Flutter App - Full Setup Script
# Run this from inside your local_ai project folder
# Usage: powershell -ExecutionPolicy Bypass -File setup_localai.ps1

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Local AI Flutter App - File Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Create directories
Write-Host "[*] Creating directories..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path "lib\models" | Out-Null
New-Item -ItemType Directory -Force -Path "lib\services" | Out-Null
New-Item -ItemType Directory -Force -Path "lib\screens" | Out-Null
Write-Host "[+] Directories ready." -ForegroundColor Green

# ── pubspec.yaml ──
Write-Host "[*] Writing pubspec.yaml..." -ForegroundColor Yellow
@'
name: local_ai
description: Local AI Chat App
publish_to: none
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.0
  provider: ^6.1.2
  shared_preferences: ^2.2.3
  flutter_markdown: ^0.7.3
  google_fonts: ^6.2.1

flutter:
  uses-material-design: true
'@ | Set-Content -Path "pubspec.yaml" -Encoding UTF8
Write-Host "[+] pubspec.yaml written." -ForegroundColor Green

# ── lib/models/chat_message.dart ──
Write-Host "[*] Writing chat_message.dart..." -ForegroundColor Yellow
@'
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
'@ | Set-Content -Path "lib\models\chat_message.dart" -Encoding UTF8
Write-Host "[+] chat_message.dart written." -ForegroundColor Green

# ── lib/models/conversation.dart ──
Write-Host "[*] Writing conversation.dart..." -ForegroundColor Yellow
@'
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
'@ | Set-Content -Path "lib\models\conversation.dart" -Encoding UTF8
Write-Host "[+] conversation.dart written." -ForegroundColor Green

# ── lib/services/ollama_service.dart ──
Write-Host "[*] Writing ollama_service.dart..." -ForegroundColor Yellow
@'
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class OllamaService {
  final String baseUrl;
  OllamaService({this.baseUrl = 'http://localhost:11434'});

  Future<bool> isRunning() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> listModels() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/tags'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['models'] as List).map((m) => m['name'] as String).toList();
      }
    } catch (_) {}
    return [];
  }

  Stream<String> chat({
    required String model,
    required List<Map<String, dynamic>> messages,
    String? systemPrompt,
  }) async* {
    final allMessages = [
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        {'role': 'system', 'content': systemPrompt},
      ...messages,
    ];
    final request = http.Request('POST', Uri.parse('$baseUrl/api/chat'));
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({'model': model, 'messages': allMessages, 'stream': true});
    try {
      final response = await request.send();
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          if (line.trim().isEmpty) continue;
          try {
            final parsed = jsonDecode(line);
            final content = parsed['message']?['content'] as String?;
            if (content != null && content.isNotEmpty) yield content;
          } catch (_) {}
        }
      }
    } catch (e) {
      yield '[Error: $e — Is Ollama running?]';
    }
  }

  Stream<Map<String, dynamic>> pullModel(String model) async* {
    final request = http.Request('POST', Uri.parse('$baseUrl/api/pull'));
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({'name': model, 'stream': true});
    final response = await request.send();
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      for (final line in chunk.split('\n')) {
        if (line.trim().isEmpty) continue;
        try { yield jsonDecode(line); } catch (_) {}
      }
    }
  }

  Future<bool> deleteModel(String model) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/api/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': model}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
'@ | Set-Content -Path "lib\services\ollama_service.dart" -Encoding UTF8
Write-Host "[+] ollama_service.dart written." -ForegroundColor Green

# ── lib/models/app_state.dart ──
Write-Host "[*] Writing app_state.dart..." -ForegroundColor Yellow
@'
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
'@ | Set-Content -Path "lib\app_state.dart" -Encoding UTF8
Write-Host "[+] app_state.dart written." -ForegroundColor Green

# ── lib/main.dart ──
Write-Host "[*] Writing main.dart..." -ForegroundColor Yellow
@'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_state.dart';
import 'screens/chat_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const LocalAIApp(),
    ),
  );
}

class LocalAIApp extends StatelessWidget {
  const LocalAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF7C6AF7),
          secondary: const Color(0xFF5EEAD4),
          surface: const Color(0xFF13131F),
          surfaceContainerHighest: const Color(0xFF1E1E2E),
          outline: const Color(0xFF2E2E45),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        scaffoldBackgroundColor: const Color(0xFF0D0D14),
      ),
      home: const ChatScreen(),
    );
  }
}
'@ | Set-Content -Path "lib\main.dart" -Encoding UTF8
Write-Host "[+] main.dart written." -ForegroundColor Green

# ── lib/screens/chat_screen.dart ──
Write-Host "[*] Writing chat_screen.dart..." -ForegroundColor Yellow
@'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../app_state.dart';
import '../models/chat_message.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send(AppState state) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    state.sendMessage(text);
    _scrollToBottom();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<AppState>(builder: (context, state, _) {
      _scrollToBottom();
      return Scaffold(
        body: Row(children: [
          // Sidebar
          Container(
            width: 240,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Column(children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 8),
                child: Row(children: [
                  Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Local AI', style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
                  const Spacer(),
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: state.ollamaOnline ? const Color(0xFF4ADE80) : const Color(0xFFEF4444),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: state.newConversation,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Chat'),
                    style: FilledButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ),
              const Divider(height: 16),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: state.conversations.length,
                  itemBuilder: (_, i) {
                    final conv = state.conversations[i];
                    final isActive = conv == state.activeConversation;
                    return ListTile(
                      dense: true,
                      selected: isActive,
                      selectedTileColor: theme.colorScheme.primary.withOpacity(0.15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      leading: Icon(Icons.chat_bubble_outline, size: 16,
                          color: isActive ? theme.colorScheme.primary : theme.colorScheme.outline),
                      title: Text(conv.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface)),
                      onTap: () => state.selectConversation(conv),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        onPressed: () => state.deleteConversation(conv),
                        color: theme.colorScheme.outline,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Model', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: state.models.contains(state.selectedModel) ? state.selectedModel : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme.colorScheme.outline)),
                    ),
                    hint: Text(state.models.isEmpty ? 'No models' : 'Select model',
                        style: theme.textTheme.bodySmall),
                    items: state.models.map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(m, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) { state.selectedModel = val; state.notifyListeners(); }
                    },
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen())),
                      icon: const Icon(Icons.tune, size: 14),
                      label: const Text('Settings & Models'),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: theme.textTheme.labelSmall),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          // Chat area
          Expanded(
            child: Column(children: [
              Expanded(
                child: state.activeConversation == null || state.activeConversation!.messages.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.auto_awesome, size: 56,
                              color: theme.colorScheme.primary.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          Text('Local AI', style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text('Running fully on your machine.',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: theme.colorScheme.outline)),
                          if (!state.ollamaOnline) ...[
                            const SizedBox(height: 12),
                            Text('⚠ Ollama is not running. Start it with: ollama serve',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: Colors.orange)),
                          ],
                        ]),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        itemCount: state.activeConversation!.messages.length,
                        itemBuilder: (_, i) =>
                            _MessageBubble(message: state.activeConversation!.messages[i]),
                      ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(children: [
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(
                        child: KeyboardListener(
                          focusNode: FocusNode(),
                          onKeyEvent: (event) {
                            if (event is KeyDownEvent &&
                                event.logicalKey == LogicalKeyboardKey.enter &&
                                !HardwareKeyboard.instance.isShiftPressed) {
                              _send(state);
                            }
                          },
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            maxLines: 6,
                            minLines: 1,
                            style: theme.textTheme.bodyMedium,
                            decoration: const InputDecoration(
                              hintText: 'Message...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: IconButton.filled(
                          onPressed: _controller.text.trim().isEmpty || state.isStreaming || state.selectedModel.isEmpty
                              ? null
                              : () => _send(state),
                          icon: state.isStreaming
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.arrow_upward),
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  Text('Enter to send · Shift+Enter for new line',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                ]),
              ),
            ]),
          ),
        ]),
      );
    });
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
              child: Icon(Icons.auto_awesome, size: 14, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser ? null : Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
              ),
              child: message.isStreaming && message.content.isEmpty
                  ? _TypingIndicator()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SelectionArea(
                          child: isUser
                              ? Text(message.content,
                                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white))
                              : MarkdownBody(
                                  data: message.content + (message.isStreaming ? ' ▋' : ''),
                                  selectable: true,
                                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                                    p: theme.textTheme.bodyMedium,
                                    code: theme.textTheme.bodySmall?.copyWith(
                                      fontFamily: 'monospace',
                                      backgroundColor: theme.colorScheme.surface,
                                    ),
                                  ),
                                ),
                        ),
                        if (!message.isStreaming) ...[
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: message.content));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Copied to clipboard'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy, size: 12,
                                    color: isUser ? Colors.white70 : theme.colorScheme.outline),
                                const SizedBox(width: 4),
                                Text('Copy',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                        color: isUser ? Colors.white70 : theme.colorScheme.outline)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.secondary.withOpacity(0.2),
              child: Icon(Icons.person_outline, size: 14, color: theme.colorScheme.secondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final opacity = ((_ctrl.value - i / 3) % 1.0 + 1.0) % 1.0 < 0.5 ? 1.0 : 0.3;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
'@ | Set-Content -Path "lib\screens\chat_screen.dart" -Encoding UTF8
Write-Host "[+] chat_screen.dart written." -ForegroundColor Green

# ── lib/screens/settings_screen.dart ──
Write-Host "[*] Writing settings_screen.dart..." -ForegroundColor Yellow
@'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _pullController = TextEditingController();
  final _systemController = TextEditingController();
  bool _isPulling = false;
  String _pullStatus = '';
  double _pullProgress = 0;

  @override
  void initState() {
    super.initState();
    _systemController.text = context.read<AppState>().systemPrompt;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<AppState>(builder: (context, state, _) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings & Models'),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('System Prompt', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _systemController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'You are a helpful assistant...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (val) => state.systemPrompt = val,
            ),
            const SizedBox(height: 32),
            Text('Pull a Model', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _pullController,
                  decoration: InputDecoration(
                    hintText: 'e.g. llama3.2, mistral, phi4-mini',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isPulling ? null : () => _pullModel(state),
                child: const Text('Pull'),
              ),
            ]),
            if (_isPulling || _pullStatus.isNotEmpty) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _pullProgress == 0 ? null : _pullProgress),
              const SizedBox(height: 4),
              Text(_pullStatus, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 32),
            Text('Installed Models', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (state.models.isEmpty)
              Text('No models installed.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline))
            else
              ...state.models.map((model) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(Icons.storage_outlined, color: theme.colorScheme.primary),
                  title: Text(model),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.redAccent,
                    onPressed: () => _deleteModel(state, model),
                  ),
                ),
              )),
          ],
        ),
      );
    });
  }

  Future<void> _pullModel(AppState state) async {
    final model = _pullController.text.trim();
    if (model.isEmpty) return;
    setState(() { _isPulling = true; _pullProgress = 0; _pullStatus = 'Starting...'; });
    await for (final progress in state.ollama.pullModel(model)) {
      setState(() {
        _pullStatus = progress['status'] ?? '';
        final completed = progress['completed'] as int?;
        final total = progress['total'] as int?;
        if (completed != null && total != null && total > 0) {
          _pullProgress = completed / total;
        }
      });
    }
    setState(() { _isPulling = false; _pullStatus = 'Done!'; });
    await state.loadModels();
    _pullController.clear();
  }

  Future<void> _deleteModel(AppState state, String model) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete model?'),
        content: Text('This will remove "$model" from your system.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await state.ollama.deleteModel(model);
      await state.loadModels();
    }
  }
}
'@ | Set-Content -Path "lib\screens\settings_screen.dart" -Encoding UTF8
Write-Host "[+] settings_screen.dart written." -ForegroundColor Green

# ── Add Windows desktop support ──
Write-Host "[*] Enabling Windows desktop support..." -ForegroundColor Yellow
flutter config --enable-windows-desktop | Out-Null
flutter create --platforms=windows . | Out-Null
Write-Host "[+] Windows desktop support enabled." -ForegroundColor Green

# ── Run flutter pub get ──
Write-Host ""
Write-Host "[*] Running flutter pub get..." -ForegroundColor Yellow
flutter pub get

# ── Build release exe ──
Write-Host ""
Write-Host "[*] Building release exe (this takes a few minutes)..." -ForegroundColor Yellow
$env:CMAKE_GENERATOR = "Visual Studio 17 2022"
flutter build windows --release

# ── Create Desktop Shortcut ──
Write-Host ""
Write-Host "[*] Creating desktop shortcut..." -ForegroundColor Yellow

$exePath = "$PWD\build\windows\x64\runner\Release\local_ai.exe"
$shortcutPath = "$env:USERPROFILE\Desktop\Local AI.lnk"

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $exePath
$shortcut.WorkingDirectory = "$PWD\build\windows\x64\runner\Release"
$shortcut.Description = "Local AI Chat App"
$shortcut.WindowStyle = 1
$shortcut.Save()

Write-Host "[+] Shortcut created on Desktop: 'Local AI'" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   All done!" -ForegroundColor Green
Write-Host "   Exe: build\windows\x64\runner\Release\local_ai.exe" -ForegroundColor White
Write-Host "   Shortcut: Desktop\Local AI" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ── Launch the app ──
Write-Host "[*] Launching Local AI..." -ForegroundColor Yellow
Start-Process $exePath