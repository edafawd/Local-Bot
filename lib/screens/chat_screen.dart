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
                            Text('âš  Ollama is not running. Start it with: ollama serve',
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
                  Text('Enter to send Â· Shift+Enter for new line',
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
                                  data: message.content + (message.isStreaming ? ' â–‹' : ''),
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
