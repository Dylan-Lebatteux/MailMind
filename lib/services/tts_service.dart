import 'package:flutter_tts/flutter_tts.dart';

/// Service de synthèse vocale (Text-to-Speech)
class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  /// Vérifie si le service est initialisé
  bool get isInitialized => _isInitialized;

  /// Vérifie si une lecture est en cours
  bool get isSpeaking => _isSpeaking;

  /// Initialise le service TTS
  Future<bool> initialize({
    String language = 'fr-FR',
    double speechRate = 0.5,
    double volume = 1.0,
    double pitch = 1.0,
  }) async {
    try {
      // Configuration de la langue
      await _flutterTts.setLanguage(language);

      // Configuration de la vitesse de parole (0.0 à 1.0)
      await _flutterTts.setSpeechRate(speechRate);

      // Configuration du volume (0.0 à 1.0)
      await _flutterTts.setVolume(volume);

      // Configuration du pitch/hauteur de voix (0.5 à 2.0)
      await _flutterTts.setPitch(pitch);

      // Callbacks pour suivre l'état
      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        print('TTS: Début de la lecture');
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        print('TTS: Fin de la lecture');
      });

      _flutterTts.setErrorHandler((message) {
        _isSpeaking = false;
        print('TTS Erreur: $message');
      });

      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
        print('TTS: Lecture annulée');
      });

      _isInitialized = true;
      return true;
    } catch (e) {
      print('Erreur lors de l\'initialisation du TTS: $e');
      return false;
    }
  }

  /// Lit un texte à voix haute
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      print('TtsService non initialisé');
      return;
    }

    if (text.isEmpty) {
      print('Texte vide, rien à lire');
      return;
    }

    try {
      // Arrêter toute lecture en cours
      if (_isSpeaking) {
        await stop();
      }

      await _flutterTts.speak(text);
    } catch (e) {
      print('Erreur lors de la lecture: $e');
    }
  }

  /// Arrête la lecture en cours
  Future<void> stop() async {
    if (!_isInitialized) {
      return;
    }

    try {
      await _flutterTts.stop();
      _isSpeaking = false;
    } catch (e) {
      print('Erreur lors de l\'arrêt: $e');
    }
  }

  /// Met en pause la lecture (non supporté sur toutes les plateformes)
  Future<void> pause() async {
    if (!_isInitialized || !_isSpeaking) {
      return;
    }

    try {
      await _flutterTts.pause();
    } catch (e) {
      print('Erreur lors de la pause: $e');
    }
  }

  /// Change la langue de synthèse
  Future<void> setLanguage(String language) async {
    if (!_isInitialized) {
      return;
    }

    try {
      await _flutterTts.setLanguage(language);
    } catch (e) {
      print('Erreur lors du changement de langue: $e');
    }
  }

  /// Change la vitesse de parole (0.0 à 1.0)
  Future<void> setSpeechRate(double rate) async {
    if (!_isInitialized) {
      return;
    }

    try {
      await _flutterTts.setSpeechRate(rate);
    } catch (e) {
      print('Erreur lors du changement de vitesse: $e');
    }
  }

  /// Change le volume (0.0 à 1.0)
  Future<void> setVolume(double volume) async {
    if (!_isInitialized) {
      return;
    }

    try {
      await _flutterTts.setVolume(volume);
    } catch (e) {
      print('Erreur lors du changement de volume: $e');
    }
  }

  /// Change le pitch/hauteur de voix (0.5 à 2.0)
  Future<void> setPitch(double pitch) async {
    if (!_isInitialized) {
      return;
    }

    try {
      await _flutterTts.setPitch(pitch);
    } catch (e) {
      print('Erreur lors du changement de pitch: $e');
    }
  }

  /// Récupère les langues disponibles
  Future<List<String>> getLanguages() async {
    try {
      final languages = await _flutterTts.getLanguages;
      return languages.cast<String>();
    } catch (e) {
      print('Erreur lors de la récupération des langues: $e');
      return [];
    }
  }

  /// Récupère les voix disponibles
  Future<List<String>> getVoices() async {
    try {
      final voices = await _flutterTts.getVoices;
      return voices.cast<String>();
    } catch (e) {
      print('Erreur lors de la récupération des voix: $e');
      return [];
    }
  }

  /// Libère les ressources
  void dispose() {
    _flutterTts.stop();
  }
}
