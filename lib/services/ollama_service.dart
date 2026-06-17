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
      yield '[Error: $e â€” Is Ollama running?]';
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
