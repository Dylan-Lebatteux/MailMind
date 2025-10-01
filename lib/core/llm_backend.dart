import '../models/conversation_context.dart';

/// Status de l'état du backend LLM
enum LLMStatus {
  notInitialized,
  downloading,
  loading,
  ready,
  thinking,
  error
}

/// Types de backends supportés
enum LLMBackendType {
  ollama,    // Desktop/Web/Mobile via HTTP
}

/// Interface abstraite pour tous les backends LLM
abstract class LLMBackend {
  /// Type du backend
  LLMBackendType get backendType;

  /// Status actuel
  LLMStatus get status;

  /// Message d'erreur si applicable
  String get errorMessage;

  /// Progrès de téléchargement (0.0 à 1.0)
  double get downloadProgress;

  /// Stream des changements de status
  Stream<LLMStatus> get statusStream;

  /// Nom du modèle utilisé
  String get modelName;

  /// Backend est-il prêt pour génération
  bool get isReady;

  /// Initialiser le backend
  Future<void> initialize();

  /// Générer une réponse
  Future<String> generateResponse(
    String userMessage,
    ConversationContext? context
  );

  /// Stream de génération en temps réel (optionnel)
  Stream<String> generateResponseStream(
    String userMessage,
    ConversationContext? context
  ) async* {
    // Implémentation par défaut : génération simple
    final response = await generateResponse(userMessage, context);
    yield response;
  }

  /// Vérifier la disponibilité du backend
  Future<bool> checkAvailability();

  /// Obtenir des informations sur le modèle
  Future<Map<String, dynamic>> getModelInfo();

  /// Nettoyer les ressources
  void dispose();

  /// Test rapide de fonctionnement
  Future<String> quickTest() async {
    try {
      return await generateResponse("Hello", null);
    } catch (e) {
      throw Exception('Backend test failed: $e');
    }
  }
}

/// Configuration pour un backend LLM
class LLMBackendConfig {
  final LLMBackendType type;
  final Map<String, dynamic> parameters;
  final String? modelPath;
  final String? serverUrl;
  final int? maxTokens;
  final double? temperature;

  const LLMBackendConfig({
    required this.type,
    this.parameters = const {},
    this.modelPath,
    this.serverUrl,
    this.maxTokens,
    this.temperature,
  });

  /// Configuration par défaut pour Ollama
  factory LLMBackendConfig.ollama({
    String serverUrl = 'http://localhost:11434',
    String model = 'qwen2.5:1.5b',
    double temperature = 0.7,
  }) {
    return LLMBackendConfig(
      type: LLMBackendType.ollama,
      serverUrl: serverUrl,
      parameters: {
        'model': model,
        'temperature': temperature,
        'top_p': 0.9,
        'top_k': 40,
      },
    );
  }

}

/// Exception spécifique aux backends LLM
class LLMBackendException implements Exception {
  final String message;
  final LLMBackendType backendType;
  final dynamic originalError;

  const LLMBackendException(
    this.message,
    this.backendType,
    [this.originalError]
  );

  @override
  String toString() {
    return 'LLMBackendException [$backendType]: $message';
  }
}

