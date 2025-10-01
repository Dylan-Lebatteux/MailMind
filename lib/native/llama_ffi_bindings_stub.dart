/// Stub pour les plateformes non-FFI (Web, Desktop sans native)
/// Cette version vide est utilisée quand FFI n'est pas disponible

// Stubs pour types FFI (pour éviter les erreurs de compilation web)
class Pointer<T> {
  int get address => 0;
}

class Int32 {}
class Uint32 {}
class Float {}
class Uint8 {}

class Opaque {}

class Struct {}

class LlamaFFIBindings {
  LlamaFFIBindings() {
    throw UnsupportedError(
      'LlamaFFI n\'est pas supporté sur cette plateforme. '
      'Utilisez OllamaBackend ou un autre backend compatible.'
    );
  }

  Pointer<LlamaModel> loadModel(String path, Pointer<LlamaContextParams> params) {
    throw UnsupportedError('FFI non disponible');
  }

  Pointer<LlamaContext> createContext(Pointer<LlamaModel> model) {
    throw UnsupportedError('FFI non disponible');
  }

  int tokenize(Pointer<LlamaContext> ctx, String text, Pointer<Int32> tokens, int max, bool bos, bool special) {
    throw UnsupportedError('FFI non disponible');
  }

  int eval(Pointer<LlamaContext> ctx, Pointer<Int32> tokens, int num, int past) {
    throw UnsupportedError('FFI non disponible');
  }

  int sampleToken(Pointer<LlamaContext> ctx) {
    throw UnsupportedError('FFI non disponible');
  }

  String tokenToPiece(Pointer<LlamaModel> model, int token) {
    throw UnsupportedError('FFI non disponible');
  }

  void freeContext(Pointer<LlamaContext> ctx) {}
  void freeModel(Pointer<LlamaModel> model) {}
}

// Types stub
class LlamaModel extends Opaque {}
class LlamaContext extends Opaque {}

class LlamaContextParams extends Struct {
  int seed = 0;
  int n_ctx = 0;
  int n_batch = 0;
  int n_threads = 0;
  double temperature = 0.0;
  double top_p = 0.0;
  int top_k = 0;

  // Accessor pour compatibilité avec le vrai code FFI
  LlamaContextParams get ref => this;
}

// Note: calloc est défini dans ffi_types_stub.dart, pas ici
