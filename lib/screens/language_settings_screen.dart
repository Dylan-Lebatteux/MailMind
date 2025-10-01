import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/voice_service.dart';

class LanguageSettingsScreen extends StatefulWidget {
  final SettingsService settingsService;
  final VoiceService voiceService;

  const LanguageSettingsScreen({
    super.key,
    required this.settingsService,
    required this.voiceService,
  });

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  String? _selectedLocale;
  bool _ttsEnabled = true;
  List<String> _availableLocales = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);

    // Charger les préférences actuelles
    _selectedLocale = widget.settingsService.getVoiceLocale();
    _ttsEnabled = widget.settingsService.isTtsEnabled();

    // Charger les langues disponibles sur l'appareil
    try {
      _availableLocales = await widget.voiceService.getAvailableLocales();
    } catch (e) {
      print('Erreur chargement langues: $e');
      _availableLocales = [];
    }

    setState(() => _loading = false);
  }

  void _saveLanguage(String? locale) {
    widget.settingsService.setVoiceLocale(locale);

    // Mettre à jour le VoiceService immédiatement
    widget.voiceService.setLocale(locale);

    setState(() => _selectedLocale = locale);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(locale == null || locale == 'auto'
            ? 'Langue : Auto-détection activée'
            : 'Langue changée : ${SettingsService.supportedLocales[locale] ?? locale}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _saveTtsEnabled(bool enabled) {
    widget.settingsService.setTtsEnabled(enabled);
    setState(() => _ttsEnabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres Langue'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Section Reconnaissance Vocale
                const Text(
                  'Reconnaissance Vocale',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Auto-détection
                Card(
                  child: RadioListTile<String?>(
                    title: const Text('🌍 Auto-détection'),
                    subtitle: const Text('Détecte automatiquement la meilleure langue'),
                    value: null,
                    groupValue: _selectedLocale,
                    onChanged: _saveLanguage,
                  ),
                ),

                const SizedBox(height: 8),

                // Langues françaises
                _buildLanguageSection('Français', ['fr_FR', 'fr_BE', 'fr_CA']),

                const SizedBox(height: 8),

                // Langues anglaises
                _buildLanguageSection('English', ['en_US', 'en_GB']),

                const SizedBox(height: 32),

                // Section TTS
                const Text(
                  'Synthèse Vocale (TTS)',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                Card(
                  child: SwitchListTile(
                    title: const Text('Lecture automatique'),
                    subtitle: const Text('Lire les réponses de l\'IA vocalement'),
                    value: _ttsEnabled,
                    onChanged: _saveTtsEnabled,
                  ),
                ),

                const SizedBox(height: 32),

                // Informations
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'Informations',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Langues disponibles sur cet appareil : ${_availableLocales.length}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '💡 Conseil : Choisissez manuellement votre langue pour une meilleure précision',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '🌐 La reconnaissance vocale nécessite une connexion Internet',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLanguageSection(String title, List<String> locales) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        ...locales.map((locale) {
          final isAvailable = _availableLocales.contains(locale);
          return Card(
            color: isAvailable ? null : Colors.grey.shade100,
            child: RadioListTile<String?>(
              title: Text(
                SettingsService.supportedLocales[locale] ?? locale,
                style: TextStyle(
                  color: isAvailable ? null : Colors.grey,
                ),
              ),
              subtitle: Text(
                isAvailable ? 'Disponible' : 'Non disponible sur cet appareil',
                style: TextStyle(
                  fontSize: 12,
                  color: isAvailable ? Colors.green : Colors.red,
                ),
              ),
              value: locale,
              groupValue: _selectedLocale,
              onChanged: isAvailable ? _saveLanguage : null,
            ),
          );
        }),
      ],
    );
  }
}
