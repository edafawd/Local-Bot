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
