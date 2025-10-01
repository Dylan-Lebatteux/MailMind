/// Service de gestion des paramètres (sans dépendances externes)
/// Utilise une simple variable en mémoire + persistance future
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  // Paramètres en mémoire
  String? _selectedLocale;
  bool _ttsEnabled = true;

  /// Langues supportées
  static const Map<String, String> supportedLocales = {
    'auto': 'Auto-détection',
    'fr_FR': '🇫🇷 Français (France)',
    'fr_BE': '🇧🇪 Français (Belgique)',
    'fr_CA': '🇨🇦 Français (Canada)',
    'en_US': '🇺🇸 English (United States)',
    'en_GB': '🇬🇧 English (United Kingdom)',
  };

  /// Initialise le service (pour compatibilité future)
  Future<void> initialize() async {
    // Pour l'instant, rien à charger
    // Plus tard : charger depuis un fichier
    print('⚙️ SettingsService initialisé');
  }

  /// Définit la langue de reconnaissance vocale
  void setVoiceLocale(String? locale) {
    _selectedLocale = locale;
    print('🌍 Langue changée: ${locale ?? "Auto-détection"}');
  }

  /// Récupère la langue de reconnaissance vocale
  /// null = auto-détection
  String? getVoiceLocale() {
    return _selectedLocale;
  }

  /// Active/désactive le TTS
  void setTtsEnabled(bool enabled) {
    _ttsEnabled = enabled;
    print('🔊 TTS ${enabled ? "activé" : "désactivé"}');
  }

  /// Vérifie si le TTS est activé
  bool isTtsEnabled() {
    return _ttsEnabled;
  }

  /// Réinitialise tous les paramètres
  void reset() {
    _selectedLocale = null;
    _ttsEnabled = true;
    print('🔄 Paramètres réinitialisés');
  }
}
