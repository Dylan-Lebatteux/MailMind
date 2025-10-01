class Email {
  final String id;
  final String from;
  final String fromName;
  final String subject;
  final String body;
  final DateTime receivedDate;
  final bool isRead;
  final bool hasAttachments;
  final List<String> attachments;

  Email({
    required this.id,
    required this.from,
    required this.fromName,
    required this.subject,
    required this.body,
    required this.receivedDate,
    this.isRead = false,
    this.hasAttachments = false,
    this.attachments = const [],
  });

  factory Email.fromJson(Map<String, dynamic> json) {
    return Email(
      id: json['id'] as String,
      from: json['from'] as String,
      fromName: json['fromName'] as String,
      subject: json['subject'] as String,
      body: json['body'] as String,
      receivedDate: DateTime.parse(json['receivedDate'] as String),
      isRead: json['isRead'] as bool? ?? false,
      hasAttachments: json['hasAttachments'] as bool? ?? false,
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from': from,
      'fromName': fromName,
      'subject': subject,
      'body': body,
      'receivedDate': receivedDate.toIso8601String(),
      'isRead': isRead,
      'hasAttachments': hasAttachments,
      'attachments': attachments,
    };
  }

  /// Résumé court pour affichage dans le contexte LLM
  String toContextString() {
    final date = '${receivedDate.day}/${receivedDate.month}/${receivedDate.year} ${receivedDate.hour}:${receivedDate.minute.toString().padLeft(2, '0')}';
    return '''
Email #${id}:
De: $fromName <$from>
Date: $date
Sujet: $subject
${isRead ? '(Lu)' : '(Non lu)'}
Contenu: $body
${hasAttachments ? 'Pièces jointes: ${attachments.join(", ")}' : ''}
''';
  }
}
