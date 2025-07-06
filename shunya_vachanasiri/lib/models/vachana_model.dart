// lib/models/vachana_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Vachana {
  final int sharanaId;
  final String vachanaId;
  final String sharanaNameKannada;
  final String sharanaNameEnglish;
  final String vachanaNameKannada;
  final String vachanaNameEnglish;
  final String vachanaLyricsKannada;
  final String vachanaLyricsEnglish;

  Vachana({
    required this.sharanaId,
    required this.vachanaId,
    required this.sharanaNameKannada,
    required this.sharanaNameEnglish,
    required this.vachanaNameKannada,
    required this.vachanaNameEnglish,
    required this.vachanaLyricsKannada,
    required this.vachanaLyricsEnglish,
  });

  factory Vachana.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Sanitize text inputs
    String? sanitize(String? input) {
      if (input == null) return null;
      // Remove invalid Unicode characters
      return input.replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F]'), '');
    }

    return Vachana(
      vachanaId: doc.id,
      sharanaId: data['sharanaId'] ?? -1,
      sharanaNameKannada: data['sharanaNameKannada'] ?? '',
      sharanaNameEnglish: data['sharanaNameEnglish'] ?? '',
      vachanaNameKannada: data['vachanaNameKannada'] ?? '',
      vachanaNameEnglish: data['vachanaNameEnglish'] ?? '',
      vachanaLyricsKannada: data['vachanaLyricsKannada'] ?? '',
      vachanaLyricsEnglish: data['vachanaLyricsEnglish'] ?? '',
    );
  }
}
