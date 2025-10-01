import 'dart:async';
import 'dart:io';
import '../core/llm_backend.dart';
import '../services/backends/ollama_backend.dart';
import '../models/conversation_context.dart';
import '../models/message.dart';
import 'email_service.dart';

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

      // Injecter le contexte des emails dans le message utilisateur
      final emailService = EmailService();
      String enrichedMessage = userMessage;

      // Si la question concerne les emails, ajouter le contexte
      if (_isEmailRelatedQuery(userMessage)) {
        enrichedMessage = _buildEmailQuery(userMessage, emailService);
        print('📧 Contexte emails ajouté à la requête');
      }

      // Générer avec le backend actuel
      final response = await _currentBackend!.generateResponse(enrichedMessage, context);

      // Mettre à jour le contexte de conversation
      _updateConversationContext(userMessage, response);

      return response;

    } catch (e) {
      print('❌ Erreur génération: $e');
      throw Exception('Erreur de génération: $e');
    }
  }

  /// Construit une requête intelligente pour les emails
  String _buildEmailQuery(String userMessage, EmailService emailService) {
    final lowerQuery = userMessage.toLowerCase();

    // Question sur le nombre total
    if (lowerQuery.contains('combien')) {
      // Détecter "non lus" ou "pas lus" ou "ne sont pas lus"
      if (lowerQuery.contains('non lu') ||
          lowerQuery.contains('pas lu') ||
          lowerQuery.contains('pas encore lu') ||
          lowerQuery.contains('ne sont pas') ||
          lowerQuery.contains('non-lu')) {
        final count = emailService.getUnreadCount();
        return 'Réponds EXACTEMENT en une phrase: Tu as $count emails non lus.';
      } else if (lowerQuery.contains('email') || lowerQuery.contains('mail')) {
        final count = emailService.getTotalCount();
        return 'Réponds EXACTEMENT en une phrase: Tu as $count emails au total.';
      }
    }

    // Question sur le dernier email (détection améliorée)
    final isAskingLatest = lowerQuery.contains('dernier') ||
                          lowerQuery.contains('récent') ||
                          lowerQuery.contains('dernier email') ||
                          lowerQuery.contains('derniere') ||
                          (lowerQuery.contains('le') && lowerQuery.contains('reçu') && lowerQuery.contains('email'));

    if (isAskingLatest) {
      final latest = emailService.getLatestEmail();
      if (latest != null) {
        return '''Tu es un assistant vocal. Lis cet email à voix haute:

De: ${latest.fromName}
Sujet: ${latest.subject}
Contenu: ${latest.body}

Reformule naturellement ce message en 2-3 phrases. STOP immédiatement après. NE COMMENTE PAS ton travail. NE DIS RIEN d'autre après avoir lu le message.''';
      }
    }

    // Question sur un email spécifique (recherche par mot-clé)
    final keywords = ['banque', 'cloud', 'réunion', 'marie', 'lucas', 'rh', 'newsletter', 'congé', 'abonnement', 'collaboration'];
    for (var keyword in keywords) {
      if (lowerQuery.contains(keyword)) {
        final results = emailService.searchEmails(keyword);
        if (results.isNotEmpty) {
          final email = results.first;
          return '''Tu es un assistant vocal. Lis cet email à voix haute:

De: ${email.fromName}
Sujet: ${email.subject}
Contenu: ${email.body}

Reformule naturellement ce message en 2-3 phrases. STOP immédiatement après. NE COMMENTE PAS ton travail. NE DIS RIEN d'autre après avoir lu le message.''';
        }
      }
    }

    // Liste des non lus
    if (lowerQuery.contains('non lu')) {
      final unread = emailService.getUnreadEmails();
      if (unread.isEmpty) {
        return 'Réponds: Tu n\'as pas d\'emails non lus.';
      }
      final list = unread.map((e) => '${e.fromName}: ${e.subject}').join(', ');
      return 'Réponds: Tu as ${unread.length} emails non lus de: $list';
    }

    // Par défaut: réponse très stricte
    return 'Réponds en UNE phrase courte: Je ne peux pas répondre à cette question sur les emails.';
  }

  /// Détecte si la question concerne les emails
  bool _isEmailRelatedQuery(String query) {
    final lowerQuery = query.toLowerCase();
    final emailKeywords = [
      'email', 'mail', 'message', 'courrier',
      'boîte', 'boite', 'réception', 'reception',
      'combien', 'dernier', 'derniere', 'lu', 'non lu',
      'reçu', 'recu', 'envoyé', 'envoye',
      'marie', 'lucas', 'banque', 'cloud', 'rh', 'newsletter',
      'réunion', 'reunion', 'abonnement', 'congé', 'conge'
    ];

    return emailKeywords.any((keyword) => lowerQuery.contains(keyword));
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