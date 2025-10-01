import 'dart:async';
import '../../core/llm_backend.dart';
import '../../models/conversation_context.dart';

/// Stub LlamaCppBackend pour plateformes non-mobiles
/// Cette version est utilisée sur Web/Desktop où FFI n'est pas disponible
class LlamaCppBackend implements LLMBackend {
  final LLMBackendConfig config;

  LlamaCppBackend(this.config);

  @override
  LLMBackendType get backendType => LLMBackendType.llamacpp;

  @override
  LLMStatus get status => LLMStatus.error;

  @override
  String get errorMessage => 'LlamaCpp backend non disponible sur cette plateforme';

  @override
  double get downloadProgress => 0.0;

  @override
  Stream<LLMStatus> get statusStream => Stream.value(LLMStatus.error);

  @override
  String get modelName => 'N/A';

  @override
  bool get isReady => false;

  @override
  Future<void> initialize() async {
    throw UnsupportedError(
      'LlamaCpp backend n\'est supporté que sur Android/iOS. '
      'Utilisez OllamaBackend sur cette plateforme.'
    );
  }

  @override
  Future<String> generateResponse(String userMessage, ConversationContext? context) async {
    throw UnsupportedError('LlamaCpp non disponible sur cette plateforme');
  }

  @override
  Stream<String> generateResponseStream(String userMessage, ConversationContext? context) async* {
    throw UnsupportedError('LlamaCpp non disponible sur cette plateforme');
  }

  @override
  Future<bool> checkAvailability() async => false;

  @override
  Future<Map<String, dynamic>> getModelInfo() async {
    return {
      'backend': 'LLaMA.cpp (non disponible)',
      'error': 'Plateforme non supportée',
    };
  }

  @override
  Future<String> quickTest() async {
    throw UnsupportedError('LlamaCpp non disponible sur cette plateforme');
  }

  @override
  void dispose() {}
}
