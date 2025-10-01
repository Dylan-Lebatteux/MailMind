import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/email.dart';

/// Service de gestion des emails (mock pour simulation)
class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  List<Email> _emails = [];
  bool _isLoaded = false;

  /// Charge les emails depuis le fichier JSON
  Future<void> loadEmails() async {
    if (_isLoaded) return;

    try {
      final String jsonString = await rootBundle.loadString('assets/mock_emails.json');
      final List<dynamic> jsonList = json.decode(jsonString);

      _emails = jsonList.map((json) => Email.fromJson(json)).toList();

      // Trier par date (plus récent en premier)
      _emails.sort((a, b) => b.receivedDate.compareTo(a.receivedDate));

      _isLoaded = true;
      print('📧 ${_emails.length} emails chargés');
    } catch (e) {
      print('❌ Erreur chargement emails: $e');
      _emails = [];
    }
  }

  /// Récupère tous les emails
  List<Email> getAllEmails() {
    return _emails;
  }

  /// Récupère les emails non lus
  List<Email> getUnreadEmails() {
    return _emails.where((email) => !email.isRead).toList();
  }

  /// Récupère un email par ID
  Email? getEmailById(String id) {
    try {
      return _emails.firstWhere((email) => email.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Récupère le dernier email reçu
  Email? getLatestEmail() {
    return _emails.isNotEmpty ? _emails.first : null;
  }

  /// Nombre total d'emails
  int getTotalCount() {
    return _emails.length;
  }

  /// Nombre d'emails non lus
  int getUnreadCount() {
    return _emails.where((email) => !email.isRead).length;
  }

  /// Marque un email comme lu
  void markAsRead(String id) {
    final email = getEmailById(id);
    if (email != null) {
      final index = _emails.indexOf(email);
      _emails[index] = Email(
        id: email.id,
        from: email.from,
        fromName: email.fromName,
        subject: email.subject,
        body: email.body,
        receivedDate: email.receivedDate,
        isRead: true,
        hasAttachments: email.hasAttachments,
        attachments: email.attachments,
      );
    }
  }

  /// Génère un contexte textuel pour le LLM
  /// Contient les informations essentielles sur les emails
  String getEmailContextForLLM() {
    if (_emails.isEmpty) {
      return "Aucun email dans la boîte de réception.";
    }

    final unreadCount = getUnreadCount();
    final totalCount = getTotalCount();

    String context = '''
=== BOÎTE DE RÉCEPTION ===
Total: $totalCount email(s)
Non lus: $unreadCount email(s)

EMAILS RÉCENTS:
''';

    // Ajouter les 5 derniers emails au contexte
    final recentEmails = _emails.take(5);
    for (var email in recentEmails) {
      context += '\n${email.toContextString()}\n---';
    }

    return context;
  }

  /// Recherche d'emails par mot-clé
  List<Email> searchEmails(String keyword) {
    final lowerKeyword = keyword.toLowerCase();
    return _emails.where((email) {
      return email.subject.toLowerCase().contains(lowerKeyword) ||
          email.body.toLowerCase().contains(lowerKeyword) ||
          email.fromName.toLowerCase().contains(lowerKeyword);
    }).toList();
  }
}
