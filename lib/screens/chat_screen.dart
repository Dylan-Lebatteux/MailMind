import 'package:flutter/material.dart';
import '../models/message.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/loading_widget.dart';
import '../services/llm_service.dart';
import '../services/voice_service.dart';
import '../services/tts_service.dart';
import '../core/llm_backend.dart';
import '../services/settings_service.dart';
import 'language_settings_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Message> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final LLMService _llmService = LLMService();
  final VoiceService _voiceService = VoiceService();
  final TtsService _ttsService = TtsService();
  final SettingsService _settingsService = SettingsService();

  bool _isTyping = false;
  bool _isListening = false;
  bool _voiceEnabled = false;
  String _recognizedText = '';

  @override
  void initState() {
    super.initState();
    if (!const bool.fromEnvironment('flutter.tests', defaultValue: false)) {
      _initializeLLM();
      _initializeVoiceServices();
    }
  }

  Future<void> _initializeLLM() async {
    await _llmService.checkInitialization();
    if (!_llmService.isReady) {
      await _llmService.initializeModel();
    }
  }

  Future<void> _initializeVoiceServices() async {
    try {
      final voiceInitialized = await _voiceService.initialize();
      final ttsInitialized = await _ttsService.initialize(
        language: 'fr-FR',
        speechRate: 0.5,
        volume: 1.0,
        pitch: 1.0,
      );

      setState(() {
        _voiceEnabled = voiceInitialized && ttsInitialized;
      });

      if (!_voiceEnabled) {
        print('Services vocaux non disponibles');
      }
    } catch (e) {
      print('Erreur d\'initialisation des services vocaux: $e');
      setState(() {
        _voiceEnabled = false;
      });
    }
  }

  Future<void> _toggleVoiceInput() async {
    if (!_voiceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Services vocaux non disponibles')),
      );
      return;
    }

    if (_isListening) {
      // 2ème clic sur le micro = arrêter ET envoyer automatiquement
      await _stopListeningAndSend();
    } else {
      // 1er clic = commencer l'écoute
      setState(() {
        _isListening = true;
        _recognizedText = '';
      });

      final selectedLocale = _settingsService.getVoiceLocale();

      await _voiceService.startListening(
        onResult: (text) {
          setState(() {
            _recognizedText = text;
            _textController.text = text;
          });
        },
        locale: selectedLocale,
      );

      // Auto-arrêt et envoi après 10 secondes
      Future.delayed(const Duration(seconds: 10), () {
        if (_isListening) {
          _stopListeningAndSend();
        }
      });
    }
  }

  Future<void> _stopListeningAndSend() async {
    await _voiceService.stopListening();
    setState(() {
      _isListening = false;
    });

    if (_recognizedText.isNotEmpty) {
      await _sendMessage(speakResponse: true);
    }
  }

  Future<void> _sendMessage({bool speakResponse = false}) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(Message(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
    });

    _textController.clear();
    _scrollToBottom();

    try {
      final conversationHistory = _messages
          .where((msg) => !msg.isUser)
          .map((msg) => msg.text)
          .toList();

      final aiResponse = await _llmService.generateResponse(text, conversationHistory);

      setState(() {
        _isTyping = false;
        _messages.add(Message(
          text: aiResponse,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });

      _scrollToBottom();

      if (speakResponse && _voiceEnabled) {
        await _ttsService.speak(aiResponse);
      }
    } catch (e) {
      setState(() {
        _isTyping = false;
        _messages.add(Message(
          text: "Désolé, j'ai rencontré un problème technique. Pouvez-vous réessayer ?",
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('MailMind'),
            const SizedBox(width: 8),
            StreamBuilder<LLMStatus>(
              stream: _llmService.statusStream,
              builder: (context, snapshot) {
                final status = snapshot.data ?? _llmService.status;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LanguageSettingsScreen(
                    settingsService: _settingsService,
                    voiceService: _voiceService,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<LLMStatus>(
        stream: _llmService.statusStream,
        builder: (context, snapshot) {
          final status = snapshot.data ?? _llmService.status;

          if (status == LLMStatus.downloading ||
              status == LLMStatus.loading ||
              status == LLMStatus.error) {
            return ModelLoadingWidget(
              status: status,
              progress: _llmService.downloadProgress,
              errorMessage: _llmService.errorMessage,
            );
          }

          return Column(
            children: [
              Expanded(
                child: _messages.isEmpty && !_isTyping
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.smart_toy,
                              size: 64,
                              color: Colors.blue,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'MailMind avec Qwen2.5',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Votre assistant conversationnel intelligent est prêt !',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Propulsé par Qwen2.5-1.5B-Instruct',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            if (_voiceEnabled) ...[
                              const SizedBox(height: 16),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.mic, size: 16, color: Colors.green),
                                  SizedBox(width: 4),
                                  Text(
                                    'Micro activé - Cliquez 2x pour envoyer',
                                    style: TextStyle(fontSize: 12, color: Colors.green),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _messages.length + (_isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length && _isTyping) {
                            return const TypingIndicator();
                          }
                          final message = _messages[index];
                          return ChatBubble(message: message);
                        },
                      ),
              ),
              if (_isListening)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.red.shade50,
                  child: Row(
                    children: [
                      const Icon(Icons.mic, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _recognizedText.isEmpty
                              ? 'Écoute en cours... (cliquez à nouveau pour envoyer)'
                              : _recognizedText,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              _buildMessageInput(),
            ],
          );
        },
      ),
    );
  }

  Color _getStatusColor(LLMStatus status) {
    switch (status) {
      case LLMStatus.ready:
        return Colors.green;
      case LLMStatus.downloading:
      case LLMStatus.loading:
        return Colors.orange;
      case LLMStatus.thinking:
        return Colors.blue;
      case LLMStatus.error:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(LLMStatus status) {
    switch (status) {
      case LLMStatus.ready:
        return 'PRÊT';
      case LLMStatus.downloading:
        return 'TÉLÉCHARGEMENT';
      case LLMStatus.loading:
        return 'CHARGEMENT';
      case LLMStatus.thinking:
        return 'RÉFLEXION';
      case LLMStatus.error:
        return 'ERREUR';
      default:
        return 'INIT';
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 4.0,
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_voiceEnabled)
            CircleAvatar(
              backgroundColor: _isListening ? Colors.red : Colors.blue,
              child: IconButton(
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                ),
                onPressed: !_isTyping ? _toggleVoiceInput : null,
              ),
            ),
          if (_voiceEnabled) const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: _llmService.isReady
                    ? 'Discutez avec MailMind, votre assistant IA...'
                    : 'MailMind se prépare... (vous pouvez déjà écrire !)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24.0),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 12.0,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
              maxLines: null,
              enabled: !_isTyping && !_isListening,
            ),
          ),
          const SizedBox(width: 12.0),
          CircleAvatar(
            backgroundColor: !_isTyping && !_isListening
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
            child: IconButton(
              icon: Icon(
                _isTyping ? Icons.hourglass_empty : Icons.send,
                color: Colors.white,
              ),
              onPressed: !_isTyping && !_isListening ? () => _sendMessage() : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _voiceService.dispose();
    _ttsService.dispose();
    super.dispose();
  }
}
