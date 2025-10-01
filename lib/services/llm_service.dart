import 'dart:async';
import 'dart:io';
import '../core/llm_backend.dart';
import '../services/backends/ollama_backend.dart';
import '../models/conversation_context.dart';
import '../models/message.dart';

/// Service principal de gestion LLM avec architecture multi-backend
class LLMService {
  static final LLMService _instance = LLMService._internal();
  factory LLMService() => _instance;
  LLMService._internal();

  // Backend actuel
  LLMBackend? _currentBackend;
  ConversationContext? _currentContext;

  // Configuration
  LLMBackendConfig? _config;
  bool _isInitialized = false;

  // Stream controllers pour compatibilité avec l'UI existante
  final StreamController<LLMStatus> _statusController = StreamController.broadcast();
  final StreamController<String> _responseStreamController = StreamController.broadcast();

  // Getters pour compatibilité avec l'interface existante
  LLMStatus get status => _currentBackend?.status ?? LLMStatus.notInitialized;
  String get errorMessage => _currentBackend?.errorMessage ?? '';
  double get downloadProgress => _currentBackend?.downloadProgress ?? 0.0;
  bool get isReady => _currentBackend?.isReady ?? false;
  String get modelName => _currentBackend?.modelName ?? 'unknown';

  Stream<LLMStatus> get statusStream => _statusController.stream;
  Stream<String> get responseStream => _responseStreamController.stream;

  /// Initialiser le service avec détection automatique du backend optimal
  Future<void> initializeModel() async {
    if (_isInitialized) return;

    try {
      print('🚀 Initialisation LLM Service avec architecture multi-backend');

      // Détecter la configuration optimale pour la plateforme
      _config = _detectOptimalBackend();
      print('🎯 Backend sélectionné: ${_config!.type}');

      // Créer le backend approprié
      _currentBackend = _createBackend(_config!);

      // S'abonner aux changements de status du backend
      _currentBackend!.statusStream.listen((status) {
        _statusController.add(status);
      });

      // Initialiser le backend
      await _currentBackend!.initialize();

      _isInitialized = true;
      print('✅ LLM Service initialisé avec succès');

    } catch (e) {
      print('❌ Erreur initialisation LLM Service: $e');
      _statusController.add(LLMStatus.error);
      rethrow;
    }
  }

  /// Initialiser avec une configuration spécifique
  Future<void> initializeWithConfig(LLMBackendConfig config) async {
    _config = config;
    await initializeModel();
  }

  /// Générer une réponse
  Future<String> generateResponse(
    String userMessage,
    List<String> conversationHistory
  ) async {
    if (_currentBackend == null || !_currentBackend!.isReady) {
      throw Exception('LLM Service non prêt');
    }

    try {
      // Convertir l'historique en contexte si nécessaire
      ConversationContext? context;
      if (conversationHistory.isNotEmpty) {
        context = _buildContextFromHistory(conversationHistory);
      } else {
        context = _currentContext;
      }

      // Générer avec le backend actuel
      final response = await _currentBackend!.generateResponse(userMessage, context);

      // Mettre à jour le contexte de conversation
      _updateConversationContext(userMessage, response);

      return response;

    } catch (e) {
      print('❌ Erreur génération: $e');
      throw Exception('Erreur de génération: $e');
    }
  }

  /// Générer une réponse en streaming
  Stream<String> generateResponseStream(
    String userMessage,
    List<String> conversationHistory
  ) async* {
    if (_currentBackend == null || !_currentBackend!.isReady) {
      throw Exception('LLM Service non prêt');
    }

    ConversationContext? context;
    if (conversationHistory.isNotEmpty) {
      context = _buildContextFromHistory(conversationHistory);
    } else {
      context = _currentContext;
    }

    await for (final token in _currentBackend!.generateResponseStream(userMessage, context)) {
      yield token;
    }
  }

  /// Vérifier l'initialisation (pour compatibilité)
  Future<void> checkInitialization() async {
    _isInitialized = false;
    _statusController.add(LLMStatus.notInitialized);
  }

  /// Obtenir des informations sur le modèle
  Future<String> getModelInfo() async {
    if (_currentBackend == null) {
      return "Backend: non initialisé";
    }

    try {
      final info = await _currentBackend!.getModelInfo();
      final buffer = StringBuffer();
      buffer.writeln('=== MailMind LLM Service ===');
      buffer.writeln('Backend: ${info['backend']}');
      buffer.writeln('Modèle: ${info['model']}');
      buffer.writeln('Status: ${info['status']}');
      buffer.writeln('Plateforme: ${info['platform']}');
      if (info['server_url'] != null) {
        buffer.writeln('Serveur: ${info['server_url']}');
      }
      buffer.writeln('Disponible: ${info['available']}');
      return buffer.toString();
    } catch (e) {
      return "Erreur récupération info: $e";
    }
  }

  /// Démarrer une nouvelle conversation
  void startNewConversation() {
    _currentContext = ConversationContext(
      messages: [],
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.now(),
    );
    print('🔄 Nouvelle conversation démarrée: ${_currentContext!.sessionId}');
  }

  /// Changer de backend dynamiquement
  Future<void> switchBackend(LLMBackendConfig newConfig) async {
    print('🔄 Changement de backend: ${_config?.type} → ${newConfig.type}');

    // Libérer l'ancien backend
    _currentBackend?.dispose();

    // Créer et initialiser le nouveau
    _config = newConfig;
    _currentBackend = _createBackend(newConfig);

    _currentBackend!.statusStream.listen((status) {
      _statusController.add(status);
    });

    await _currentBackend!.initialize();
    print('✅ Backend changé avec succès');
  }

  /// Nettoyer les ressources
  void dispose() {
    _currentBackend?.dispose();
    _statusController.close();
    _responseStreamController.close();
    print('🗑️ LLM Service libéré');
  }

  // === Méthodes privées ===

  /// Détecter le backend optimal selon la plateforme
  LLMBackendConfig _detectOptimalBackend() {
    if (_isMobilePlatform()) {
      print('📱 Plateforme mobile détectée - Ollama Backend sélectionné');
      // Sur émulateur Android, 10.0.2.2 pointe vers le PC hôte
      // Sur device physique ou iOS, utilisez l'IP locale de votre PC
      return LLMBackendConfig.ollama(
        serverUrl: 'http://10.0.2.2:11434',
        model: 'qwen2.5:1.5b',
      );
    } else if (_isWebPlatform()) {
      print('🌐 Plateforme web détectée - Ollama Backend sélectionné');
      return LLMBackendConfig.ollama();
    } else {
      print('🖥️ Plateforme desktop détectée - Ollama Backend sélectionné');
      return LLMBackendConfig.ollama();
    }
  }

  /// Créer un backend selon la configuration
  LLMBackend _createBackend(LLMBackendConfig config) {
    switch (config.type) {
      case LLMBackendType.ollama:
        return OllamaBackend(config);
    }
  }

  /// Construire un contexte à partir de l'historique de conversation
  ConversationContext _buildContextFromHistory(List<String> history) {
    final messages = <Message>[];

    for (int i = 0; i < history.length; i += 2) {
      if (i + 1 < history.length) {
        // Message utilisateur
        messages.add(Message(
          text: history[i],
          isUser: true,
          timestamp: DateTime.now().subtract(Duration(minutes: history.length - i)),
        ));

        // Réponse assistant
        messages.add(Message(
          text: history[i + 1],
          isUser: false,
          timestamp: DateTime.now().subtract(Duration(minutes: history.length - i - 1)),
        ));
      }
    }

    return ConversationContext(
      messages: messages,
      sessionId: _currentContext?.sessionId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: _currentContext?.startTime ?? DateTime.now(),
    );
  }

  /// Mettre à jour le contexte de conversation
  void _updateConversationContext(String userMessage, String aiResponse) {
    if (_currentContext == null) {
      startNewConversation();
    }

    // Ajouter le message utilisateur
    final userMsg = Message(
      text: userMessage,
      isUser: true,
      timestamp: DateTime.now(),
    );

    // Ajouter la réponse IA
    final aiMsg = Message(
      text: aiResponse,
      isUser: false,
      timestamp: DateTime.now(),
    );

    _currentContext = _currentContext!.addMessage(userMsg).addMessage(aiMsg);

    // Limiter la taille du contexte si nécessaire
    if (_currentContext!.needsSummarization()) {
      _currentContext = _currentContext!.createCondensedContext();
      print('📝 Contexte condensé pour optimiser les performances');
    }
  }

  // Détection de plateforme simplifiée
  bool _isMobilePlatform() {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      return false;
    }
  }

  bool _isWebPlatform() {
    return identical(0, 0.0); // true sur web
  }

  // === Méthodes de compatibilité avec l'ancienne interface ===

  /// Mode IA réelle (pour compatibilité)
  void setRealAIMode(bool enabled) {
    print('Mode IA réelle: ${enabled ? "activé" : "désactivé"}');
    // Dans la nouvelle architecture, toujours en mode réel
  }
}