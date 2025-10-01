import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service de reconnaissance vocale (Speech-to-Text)
class VoiceService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String? _selectedLocale;
  List<LocaleName> _availableLocales = [];

  /// Vérifie si le service est initialisé
  bool get isInitialized => _isInitialized;

  /// Vérifie si le micro est en cours d'écoute
  bool get isListening => _isListening;

  /// Initialise le service de reconnaissance vocale
  /// [preferredLocale] - Langue préférée (optionnel, depuis les préférences)
  Future<bool> initialize({String? preferredLocale}) async {
    try {
      // Vérifier et demander la permission du micro
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        print('❌ Permission du microphone refusée');
        return false;
      }

      // Initialiser Speech-to-Text avec debug activé
      _isInitialized = await _speechToText.initialize(
        onError: (error) => print('❌ Erreur Speech-to-Text: $error'),
        onStatus: (status) => print('📊 Status Speech-to-Text: $status'),
        debugLogging: true, // Active les logs détaillés
      );

      // Vérifier les langues disponibles
      if (_isInitialized) {
        _availableLocales = await _speechToText.locales();
        print('🌍 Langues disponibles: ${_availableLocales.length}');

        // Utiliser la langue préférée si spécifiée, sinon auto-détection
        if (preferredLocale != null && preferredLocale.isNotEmpty) {
          _selectedLocale = preferredLocale;
          print('✅ Langue forcée (depuis préférences): $_selectedLocale');
        } else {
          // Chercher français en priorité pour auto-détection
          final frenchLocale = _availableLocales.firstWhere(
            (l) => l.localeId.startsWith('fr'),
            orElse: () => _availableLocales.firstWhere(
              (l) => l.localeId.startsWith('en'),
              orElse: () => _availableLocales.first,
            ),
          );
          _selectedLocale = frenchLocale.localeId;
          print('✅ Langue auto-détectée: $_selectedLocale (${frenchLocale.name})');
        }
      }

      return _isInitialized;
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation du micro: $e');
      return false;
    }
  }

  /// Récupère la liste des langues disponibles
  Future<List<String>> getAvailableLocales() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _availableLocales.map((l) => l.localeId).toList();
  }

  /// Change la langue de reconnaissance vocale
  void setLocale(String? locale) {
    _selectedLocale = locale;
    if (locale != null) {
      print('🌍 Langue changée: $locale');
    } else {
      print('🌍 Langue: Auto-détection');
    }
  }

  /// Démarre l'écoute vocale
  /// [onResult] - Callback appelé avec le texte reconnu
  /// [locale] - Langue de reconnaissance (utilise la langue sauvegardée si null)
  Future<void> startListening({
    required Function(String) onResult,
    String? locale,
  }) async {
    if (!_isInitialized) {
      print('❌ VoiceService non initialisé');
      return;
    }

    if (_isListening) {
      print('⚠️ Déjà en cours d\'écoute');
      return;
    }

    final localeToUse = locale ?? _selectedLocale ?? 'en_US';

    try {
      // Convertir le format de locale si nécessaire (fr_FR -> fr-FR)
      final androidLocale = localeToUse.replaceAll('_', '-');
      print('🎤 Démarrage de l\'écoute avec locale: $androidLocale');

      await _speechToText.listen(
        onResult: (result) {
          print('📝 Résultat reçu: "${result.recognizedWords}" (final: ${result.finalResult}, confidence: ${result.confidence})');
          // Envoyer les résultats partiels et finaux
          if (result.recognizedWords.isNotEmpty) {
            onResult(result.recognizedWords);
          }
        },
        localeId: androidLocale,
        // Mode dictation pour une écoute continue
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        cancelOnError: false,
        partialResults: true,
        // NOUVEAU: Forcer la langue sans auto-détection
        onDevice: false, // Utiliser le cloud pour meilleure précision
        listenMode: ListenMode.confirmation, // Mode qui attend confirmation
        sampleRate: 16000, // Qualité audio standard
      );

      _isListening = true;
      print('✅ Écoute démarrée avec succès');
    } catch (e) {
      print('❌ Erreur lors du démarrage de l\'écoute: $e');
    }
  }

  /// Arrête l'écoute vocale
  Future<void> stopListening() async {
    if (!_isListening) {
      return;
    }

    try {
      await _speechToText.stop();
      _isListening = false;
      print('⏹️ Écoute arrêtée');
    } catch (e) {
      print('❌ Erreur lors de l\'arrêt de l\'écoute: $e');
    }
  }

  /// Annule l'écoute en cours
  Future<void> cancel() async {
    if (!_isListening) {
      return;
    }

    try {
      await _speechToText.cancel();
      _isListening = false;
      print('🚫 Écoute annulée');
    } catch (e) {
      print('❌ Erreur lors de l\'annulation: $e');
    }
  }

  /// Vérifie si la reconnaissance vocale est disponible sur l'appareil
  Future<bool> isAvailable() async {
    try {
      return await _speechToText.initialize();
    } catch (e) {
      return false;
    }
  }

  /// Libère les ressources
  void dispose() {
    _speechToText.cancel();
  }
}
