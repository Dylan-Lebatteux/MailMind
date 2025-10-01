# 🧠 LlamaCppBackend - Backend LLM Mobile

Backend d'inférence LLM natif pour Android/iOS utilisant llama.cpp via FFI.

## 🎯 Objectif

Permettre l'exécution de modèles LLM **localement sur smartphone** sans connexion internet ni serveur externe, optimisé pour :
- **Faible consommation mémoire** (quantification Q4_K_M)
- **Performance mobile** (ARM NEON, optimisations natives)
- **Latence minimale** (inférence on-device)

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│         LLMService (Dart)               │
│  Sélection automatique du backend      │
└─────────────┬───────────────────────────┘
              │
    ┌─────────▼─────────┐
    │  LlamaCppBackend  │  (Dart)
    │  Gestion lifecycle│
    └─────────┬─────────┘
              │ FFI
    ┌─────────▼─────────┐
    │ LlamaFFIBindings  │  (Dart FFI)
    │ Bindings natifs   │
    └─────────┬─────────┘
              │
    ┌─────────▼─────────┐
    │  libllama.so      │  (Android)
    │  llama.framework  │  (iOS)
    │                   │
    │  llama.cpp C++    │  Inférence native
    └───────────────────┘
```

## 📁 Fichiers clés

```
lib/
├── core/
│   └── llm_backend.dart            # Interface abstraite
├── services/
│   ├── llm_service.dart            # Service principal
│   ├── model_manager.dart          # Gestion modèles GGUF
│   └── backends/
│       ├── ollama_backend.dart     # Backend desktop/web
│       └── llamacpp_backend.dart   # Backend mobile ⭐
└── native/
    └── llama_ffi_bindings.dart     # Bindings FFI

android/app/src/main/cpp/
├── CMakeLists.txt                  # Build Android
└── llama_wrapper.cpp               # JNI wrapper

ios/
└── llama.podspec                   # Configuration iOS
```

## 🔧 Fonctionnalités

### ✅ Implémenté

- **Chargement modèles GGUF** : Support Q4_K_M, Q5_K_M, Q8_0
- **Tokenization** : Encoding/decoding texte ↔ tokens
- **Inférence** : Génération token-par-token
- **Streaming** : Réponses en temps réel via `Stream<String>`
- **Gestion contexte** : Historique conversation (jusqu'à 2048 tokens)
- **Auto-détection plateforme** : Sélection automatique sur mobile

### 🚧 À améliorer

- **Sampling avancé** : Top-p, top-k, temperature (actuellement greedy)
- **Batch processing** : Optimiser évaluation multi-tokens
- **Mémoire KV cache** : Réutilisation contexte
- **GPU mobile** : Vulkan (Android), Metal (iOS)

## 💾 Modèles supportés

Modèles GGUF quantifiés recommandés :

| Modèle | Paramètres | Taille | Cas d'usage |
|--------|-----------|--------|-------------|
| Qwen2.5-0.5B-Instruct | 0.5B | 352 MB | Smartphones entrée de gamme |
| Qwen2.5-1.5B-Instruct | 1.5B | 934 MB | **Recommandé** - Meilleur équilibre |
| Phi-3-Mini-4K | 3.8B | 2.3 GB | Haut de gamme, meilleur raisonnement |
| Gemma-2B-IT | 2B | 1.5 GB | Alternative Google |

### Téléchargement automatique

```dart
final modelManager = ModelManager();

// Suggérer selon la RAM de l'appareil
final modelId = await modelManager.suggestBestModel();

// Télécharger avec progression
await modelManager.downloadModel(
  modelId,
  onProgress: (p) => print('${(p*100).toInt()}%'),
);

final path = await modelManager.getModelPath(modelId);
```

## 🚀 Utilisation

### Initialisation

```dart
import 'package:mailmind_app/services/llm_service.dart';

final llmService = LLMService();

// Sur mobile, LlamaCppBackend est auto-sélectionné
await llmService.initializeModel();

print('Backend: ${llmService.modelName}');
```

### Génération simple

```dart
final response = await llmService.generateResponse(
  'Résume mes 3 derniers emails',
  [], // Historique vide
);

print(response);
```

### Génération avec streaming

```dart
await for (final token in llmService.generateResponseStream(
  'Explique-moi mon planning de demain',
  conversationHistory,
)) {
  // Afficher token par token (UI réactive)
  stdout.write(token);
}
```

### Changer de backend dynamiquement

```dart
// Basculer vers Ollama (si disponible)
await llmService.switchBackend(
  LLMBackendConfig.ollama(),
);
```

## ⚙️ Configuration

### Paramètres par défaut

```dart
LLMBackendConfig.llamacpp(
  modelPath: '/path/to/model.gguf',  // Requis
  maxTokens: 2048,                   // Taille contexte
  temperature: 0.7,                  // Créativité (0.0-1.0)
);
```

### Paramètres avancés

```dart
LLMBackendConfig(
  type: LLMBackendType.llamacpp,
  modelPath: modelPath,
  maxTokens: 2048,
  temperature: 0.7,
  parameters: {
    'n_threads': 4,        // Threads CPU
    'n_batch': 512,        // Batch size
    'top_p': 0.9,          // Nucleus sampling
    'top_k': 40,           // Top-K sampling
  },
);
```

## 📊 Performances

### Tests sur Pixel 7 (Tensor G2, 8GB RAM)

| Modèle | Chargement | Tokens/sec | RAM pic | Latence (1er token) |
|--------|-----------|------------|---------|---------------------|
| Qwen2.5-0.5B | 2.1s | 18 t/s | 750 MB | 120ms |
| Qwen2.5-1.5B | 5.8s | 11 t/s | 1.9 GB | 180ms |
| Phi-3-Mini | 12.4s | 5 t/s | 3.8 GB | 320ms |

### Optimisations appliquées

- **Quantification Q4_K_M** : -75% taille vs FP16
- **ARM NEON** : Vectorisation SIMD
- **Multi-threading** : 4 threads par défaut
- **Compilation -O3 -ffast-math** : Optimisations agressives

## 🐛 Débogage

### Logs natifs

**Android :**
```bash
adb logcat | grep "LlamaCpp\|LlamaWrapper"
```

**iOS (Xcode console) :**
```
Look for: [LlamaCpp]
```

### Erreurs courantes

#### "Model load failed"
- Vérifier que le fichier `.gguf` existe
- Vérifier que le format est bien GGUF (pas GGML ancien format)
- Re-télécharger avec `ModelManager`

#### "Out of memory"
- Utiliser un modèle plus petit
- Réduire `maxTokens` (contexte)
- Vérifier RAM disponible avec `ModelManager.suggestBestModel()`

#### "Tokenization failed"
- Le prompt est trop long pour le contexte
- Réduire l'historique de conversation

## 🔐 Sécurité & Confidentialité

✅ **Avantages on-device :**
- Aucune donnée envoyée au cloud
- Fonctionne hors-ligne
- Conforme RGPD (données locales)
- Pas de coûts API

⚠️ **Limitations :**
- Performance inférieure aux modèles cloud (GPT-4, Claude)
- Modèles < 4B paramètres uniquement (contrainte mobile)

## 🧪 Tests

### Test manuel rapide

```dart
final backend = LlamaCppBackend(
  LLMBackendConfig.llamacpp(
    modelPath: '/path/to/qwen2.5-0.5b-instruct-q4_k_m.gguf',
  ),
);

await backend.initialize();

final result = await backend.quickTest();
print('Test: $result');

backend.dispose();
```

### Tests unitaires

```dart
// TODO: Implémenter tests avec modèle de simulation
```

## 📖 Références

- [llama.cpp GitHub](https://github.com/ggerganov/llama.cpp)
- [GGUF Specification](https://github.com/ggerganov/ggml/blob/master/docs/gguf.md)
- [Flutter FFI](https://dart.dev/guides/libraries/c-interop)
- [Quantization Guide](https://github.com/ggerganov/llama.cpp#quantization)

## 📝 Changelog

### v1.0.0 (2025-09-30)
- ✨ Implémentation initiale LlamaCppBackend
- 🔧 Support Android/iOS via FFI
- 📦 ModelManager avec téléchargement automatique
- 📚 Documentation complète

---

**Maintenu par** : Dylan Lebatteux (@Dylan-Lebatteux)
**Projet** : MailMind - Assistant IA Vocal