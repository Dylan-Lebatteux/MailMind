import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../core/llm_backend.dart';
import '../../models/conversation_context.dart';

/// Backend Ollama pour desktop/web
class OllamaBackend implements LLMBackend {
  late final LLMBackendConfig _config;
  LLMStatus _status = LLMStatus.notInitialized;
  String _errorMessage = '';
  double _downloadProgress = 0.0;
  bool _isInitialized = false;

  final StreamController<LLMStatus> _statusController = StreamController.broadcast();
  final Random _random = Random();

  // Configuration par défaut
  static const String defaultModel = 'qwen2.5:3b';
  static const String defaultServerUrl = 'http://localhost:11434';
  static const String systemPrompt = """Tu es MailMind, un assistant conversationnel intelligent et amical. Tu discutes naturellement en français et anglais. Tu es spécialisé dans l'aide à la gestion d'emails et la productivité. Réponds de manière précise, concise et directe. Suis exactement les instructions données sans ajouter d'informations non demandées.""";

  OllamaBackend([LLMBackendConfig? config]) {
    _config = config ?? LLMBackendConfig.ollama();
  }

  @override
  LLMBackendType get backendType => LLMBackendType.ollama;

  @override
  LLMStatus get status => _status;

  @override
  String get errorMessage => _errorMessage;

  @override
  double get downloadProgress => _downloadProgress;

  @override
  Stream<LLMStatus> get statusStream => _statusController.stream;

  @override
  String get modelName => _config.parameters['model'] ?? defaultModel;

  @override
  bool get isReady => _status == LLMStatus.ready;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _updateStatus(LLMStatus.loading);
      print('🔥 Initialisation Ollama Backend');

      // Test de connexion à Ollama
      await _testOllamaConnection();

      _updateStatus(LLMStatus.ready);
      _isInitialized = true;
      print('🧠 Ollama Backend activé avec succès !');

    } catch (e) {
      print('❌ Erreur Ollama Backend: $e');
      _errorMessage = 'Erreur lors de l\'initialisation Ollama: ${e.toString()}';
      _updateStatus(LLMStatus.error);
    }
  }

  @override
  Future<bool> checkAvailability() async {
    try {
      final response = await http.get(
        Uri.parse('${_config.serverUrl}/api/tags'),
      ).timeout(Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> _testOllamaConnection() async {
    final response = await http.get(
      Uri.parse('${_config.serverUrl}/api/tags'),
    ).timeout(Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('Ollama non disponible sur ${_config.serverUrl}');
    }
  }

  @override
  Future<String> generateResponse(
    String userMessage,
    ConversationContext? context
  ) async {
    if (!isReady) {
      throw LLMBackendException(
        'Backend non prêt pour génération',
        backendType
      );
    }

    _updateStatus(LLMStatus.thinking);

    try {
      print('🧠 Génération avec Ollama Backend');
      return await _generateWithOllama(userMessage, context);
    } catch (e) {
      print('❌ Erreur génération Ollama: $e');
      _updateStatus(LLMStatus.ready);
      throw LLMBackendException(
        'Erreur génération: $e',
        backendType,
        e
      );
    }
  }

  Future<String> _generateWithOllama(
    String userMessage,
    ConversationContext? context
  ) async {
    final prompt = _buildPrompt(userMessage, context);

    final response = await http.post(
      Uri.parse('${_config.serverUrl}/api/generate'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: _buildRequestBody(prompt),
    ).timeout(Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = _parseResponse(response.body);
      if (data['response'] != null) {
        final result = _cleanResponse(data['response'] as String, prompt);
        _updateStatus(LLMStatus.ready);
        print('🤖 Réponse générée par Ollama: $result');
        return result;
      }
    }

    throw Exception('Erreur API Ollama: ${response.statusCode}');
  }

  String _buildPrompt(String userMessage, ConversationContext? context) {
    final buffer = StringBuffer();

    // Format de prompt Qwen2.5-Instruct
    buffer.writeln('<|im_start|>system');
    buffer.writeln(systemPrompt);
    buffer.writeln('<|im_end|>');

    // Ajouter le contexte récent si disponible
    if (context != null && context.messages.isNotEmpty) {
      final recent = context.getRecentContext(maxMessages: 3);
      for (final msg in recent) {
        buffer.writeln('<|im_start|>${msg.isUser ? "user" : "assistant"}');
        buffer.writeln(msg.text);
        buffer.writeln('<|im_end|>');
      }
    }

    // Message utilisateur actuel
    buffer.writeln('<|im_start|>user');
    buffer.writeln(userMessage);
    buffer.writeln('<|im_end|>');

    buffer.write('<|im_start|>assistant');

    return buffer.toString();
  }

  String _buildRequestBody(String prompt) {
    final requestMap = {
      'model': modelName,
      'prompt': prompt,
      'stream': false,
      'options': {
        'temperature': _config.temperature ?? 0.7,
        'top_p': 0.9,
        'top_k': 40,
      }
    };
    return jsonEncode(requestMap);
  }

  Map<String, dynamic> _parseResponse(String responseBody) {
    try {
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (e) {
      print('❌ Erreur parsing JSON: $e');
      return {};
    }
  }

  String _cleanResponse(String response, String prompt) {
    String cleaned = response;

    // Supprimer le prompt de la réponse
    if (cleaned.contains('<|im_end|>')) {
      cleaned = cleaned.split('<|im_end|>').last.trim();
    }
    if (cleaned.contains('assistant')) {
      cleaned = cleaned.split('assistant').last.trim();
    }

    // Nettoyer les artefacts
    cleaned = cleaned
        .replaceAll(RegExp(r'<[^>]*>'), '') // Supprimer HTML/XML
        .replaceAll(RegExp(r'\\n+'), ' ') // Remplacer multiples newlines
        .replaceAll('\\n', ' ')
        .trim();

    if (cleaned.isEmpty) {
      return 'Je ne peux pas répondre à cette question pour le moment.';
    }

    return cleaned;
  }

  @override
  Stream<String> generateResponseStream(
    String userMessage,
    ConversationContext? context
  ) async* {
    // Pour l'instant, simulation streaming avec la réponse complète
    final response = await generateResponse(userMessage, context);
    final words = response.split(' ');

    for (int i = 0; i < words.length; i++) {
      final token = i == 0 ? words[i] : ' ${words[i]}';
      yield token;
      await Future.delayed(Duration(milliseconds: 50));
    }
  }

  @override
  Future<Map<String, dynamic>> getModelInfo() async {
    try {
      final available = await checkAvailability();
      return {
        'backend': 'ollama',
        'model': modelName,
        'server_url': _config.serverUrl,
        'status': status.toString(),
        'available': available,
        'platform': 'desktop/web',
      };
    } catch (e) {
      return {
        'backend': 'ollama',
        'error': e.toString(),
        'available': false,
      };
    }
  }

  void _updateStatus(LLMStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  @override
  Future<String> quickTest() async {
    try {
      return await generateResponse("Bonjour", null);
    } catch (e) {
      throw Exception('Backend test failed: $e');
    }
  }

  @override
  void dispose() {
    _statusController.close();
    print('🗑️ Ollama Backend libéré');
  }

  String get _serverUrl => _config.serverUrl ?? defaultServerUrl;
}