# MailMind - AI Voice Assistant 🤖🎙️

MailMind is an intelligent voice-powered conversational assistant built with Flutter and powered by Ollama's Qwen2.5-1.5B model. Have natural conversations with AI using voice input and receive spoken responses.

## ✨ Features

- 🎤 **Voice Input (Speech-to-Text)**: Speak naturally in French or English
- 🔊 **Voice Output (Text-to-Speech)**: Hear AI responses read aloud
- 🌍 **Multilingual Support**:
  - French (France, Belgium, Canada)
  - English (US, UK)
  - Auto-detection mode
- 🧠 **Local AI**: Powered by Ollama with Qwen2.5-1.5B-Instruct model
- ⚡ **Real-time Processing**: Fast response times with streaming support
- 📱 **Cross-platform**: Works on Android, iOS, and desktop platforms
- ⚙️ **Customizable Settings**: Choose your preferred language for voice recognition

## 🏗️ Architecture

```
mailmind_app_v2/
├── lib/
│   ├── core/
│   │   └── llm_backend.dart          # Backend interface
│   ├── models/
│   │   └── message.dart              # Message data model
│   ├── screens/
│   │   ├── chat_screen.dart          # Main chat interface
│   │   └── language_settings_screen.dart  # Language settings
│   ├── services/
│   │   ├── backends/
│   │   │   └── ollama_backend.dart   # Ollama API integration
│   │   ├── llm_service.dart          # LLM orchestration
│   │   ├── voice_service.dart        # Speech-to-Text
│   │   ├── tts_service.dart          # Text-to-Speech
│   │   └── settings_service.dart     # App settings
│   ├── widgets/
│   │   ├── chat_bubble.dart          # Message UI component
│   │   └── loading_widget.dart       # Loading states
│   └── main.dart                     # App entry point
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.0+)
- Dart SDK (3.0+)
- Ollama installed and running
- Qwen2.5-1.5B-Instruct model downloaded

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/mailmind_app_v2.git
cd mailmind_app_v2
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Set up Ollama**
```bash
# Install Ollama (if not already installed)
curl -fsSL https://ollama.com/install.sh | sh

# Pull the Qwen model
ollama pull qwen2.5:1.5b-instruct
```

4. **Configure backend URL**

Edit `lib/services/backends/ollama_backend.dart` if your Ollama server is not on `localhost:11434`:
```dart
static const String baseUrl = 'http://YOUR_SERVER_IP:11434';
```

5. **Run the app**
```bash
flutter run
```

## 📱 Usage

### Voice Interaction

1. **Tap the microphone button** to start recording
2. **Speak your question** in your selected language
3. **Tap the microphone again** or wait 10 seconds to automatically send
4. The AI will respond both in text and voice

### Change Language

1. Tap the **settings icon** (⚙️) in the top-right corner
2. Select your preferred language:
   - 🌍 Auto-detection (default)
   - 🇫🇷 Français (France/Belgique/Canada)
   - 🇺🇸 English (US/UK)
3. Return to chat and use the microphone

## 🔧 Configuration

### Voice Recognition Settings

The app uses Google's Speech Recognition API through the `speech_to_text` package. Language is automatically formatted for Android compatibility (e.g., `fr_FR` → `fr-FR`).

### Text-to-Speech Settings

TTS is configured with:
- Speech rate: 0.5
- Volume: 1.0
- Pitch: 1.0
- Language: Matches voice recognition language

### LLM Backend

Currently supports Ollama backend. The architecture allows easy addition of other backends (OpenAI, Anthropic, etc.) by implementing the `LLMBackend` interface.

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0                    # HTTP client
  speech_to_text: ^6.6.2          # Voice input
  flutter_tts: ^4.2.0             # Voice output
  permission_handler: ^11.3.1     # Android permissions
```

## 🛣️ Roadmap

- [ ] Conversation history persistence
- [ ] Multiple AI model support (GPT-4, Claude, etc.)
- [ ] Voice customization (pitch, rate, volume controls)
- [ ] Dark mode theme
- [ ] Export conversations
- [ ] Offline voice recognition

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- [Ollama](https://ollama.com/) - Local LLM inference
- [Qwen2.5](https://qwenlm.github.io/) - Language model
- [Flutter](https://flutter.dev/) - UI framework
- [speech_to_text](https://pub.dev/packages/speech_to_text) - Voice recognition
- [flutter_tts](https://pub.dev/packages/flutter_tts) - Text-to-speech

## 📧 Contact

For questions or support, please open an issue on GitHub.

---

**Made with ❤️ using Flutter and Ollama**
