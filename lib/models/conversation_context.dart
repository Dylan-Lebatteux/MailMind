import 'message.dart';

class ConversationContext {
  final List<Message> messages;
  final String sessionId;
  final DateTime startTime;
  final Map<String, dynamic> metadata;

  ConversationContext({
    required this.messages,
    required this.sessionId,
    required this.startTime,
    this.metadata = const {},
  });

  // Obtenir le contexte récent pour l'IA (derniers N messages)
  List<Message> getRecentContext({int maxMessages = 10}) {
    if (messages.length <= maxMessages) {
      return List.from(messages);
    }
    return messages.sublist(messages.length - maxMessages);
  }

  // Obtenir uniquement les messages de l'utilisateur
  List<Message> getUserMessages() {
    return messages.where((msg) => msg.isUser).toList();
  }

  // Obtenir uniquement les messages de l'assistant
  List<Message> getAssistantMessages() {
    return messages.where((msg) => !msg.isUser).toList();
  }

  // Calculer la longueur de la conversation en tokens (estimation)
  int estimateTokenCount() {
    int totalTokens = 0;
    for (final message in messages) {
      // Estimation approximative : ~0.75 tokens par mot
      totalTokens += (message.text.split(' ').length * 0.75).round();
    }
    return totalTokens;
  }

  // Obtenir un résumé de la conversation
  String getConversationSummary() {
    if (messages.isEmpty) return "Nouvelle conversation";

    final userMsgCount = getUserMessages().length;
    final assistantMsgCount = getAssistantMessages().length;
    final duration = DateTime.now().difference(startTime);

    return "Session: $userMsgCount messages utilisateur, "
           "$assistantMsgCount réponses assistant, "
           "durée: ${duration.inMinutes}min";
  }

  // Vérifier si la conversation nécessite un résumé (trop longue)
  bool needsSummarization({int maxTokens = 1500}) {
    return estimateTokenCount() > maxTokens;
  }

  // Créer un contexte condensé pour économiser les tokens
  ConversationContext createCondensedContext({int maxMessages = 6}) {
    final recentMessages = getRecentContext(maxMessages: maxMessages);

    return ConversationContext(
      messages: recentMessages,
      sessionId: sessionId,
      startTime: startTime,
      metadata: {
        ...metadata,
        'condensed': true,
        'original_message_count': messages.length,
      },
    );
  }

  // Ajouter un message au contexte
  ConversationContext addMessage(Message message) {
    final updatedMessages = List<Message>.from(messages)..add(message);

    return ConversationContext(
      messages: updatedMessages,
      sessionId: sessionId,
      startTime: startTime,
      metadata: metadata,
    );
  }

  // Exporter la conversation en format texte
  String exportToText() {
    final buffer = StringBuffer();
    buffer.writeln('=== MailMind Conversation ===');
    buffer.writeln('Session ID: $sessionId');
    buffer.writeln('Date: ${startTime.toIso8601String()}');
    buffer.writeln('Messages: ${messages.length}');
    buffer.writeln('Duration: ${DateTime.now().difference(startTime).inMinutes} minutes');
    buffer.writeln('');

    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
      final role = message.isUser ? 'USER' : 'ASSISTANT';
      buffer.writeln('[$role] ${message.formattedTime}');
      buffer.writeln(message.text);
      buffer.writeln('');
    }

    return buffer.toString();
  }

  // Analyser les sujets de conversation
  List<String> extractTopics() {
    final allText = messages.map((m) => m.text.toLowerCase()).join(' ');
    final words = allText.split(RegExp(r'\W+'));
    final wordCounts = <String, int>{};

    // Compter les mots significatifs (plus de 3 caractères)
    for (final word in words) {
      if (word.length > 3) {
        wordCounts[word] = (wordCounts[word] ?? 0) + 1;
      }
    }

    // Retourner les mots les plus fréquents
    final sortedWords = wordCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedWords
        .take(5)
        .map((entry) => entry.key)
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'start_time': startTime.toIso8601String(),
      'message_count': messages.length,
      'estimated_tokens': estimateTokenCount(),
      'topics': extractTopics(),
      'metadata': metadata,
    };
  }
}