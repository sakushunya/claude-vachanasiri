// lib/providers/app_state.dart

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shunya_vachanasiri/models/vachana_model.dart';

class AppConstants {
  static const String shunyaVachanaSiriFirebaseProjectId = 'APP-ID';
  static const String svsFSBucketBaseURL =
      'https://firebasestorage.googleapis.com/v0/b/$shunyaVachanaSiriFirebaseProjectId.firebasestorage.app/o';

  static const String sharanaCoverArtDir =
      'shunyaVachanaSiri/svsVachanaArtCover';

  static const String sharanaMiniImgDir = 'shunyaVachanaSiri/svsSharanaImage';

  static const String vachanaAudioTrackDir =
      'shunyaVachanaSiri/svsAudioTrack/langKannada';

  // Image URL generation
  static String getSharanaImageUrl(int sharanaId, String imgType) {
    // Add default/fallback logic
    if (sharanaId <= 0) {
      debugPrint('Invalid sharanaId: $sharanaId');
      return '';
    }
    // Validate image type
    final validTypes = ['coverart', 'mini'];
    if (!validTypes.contains(imgType)) {
      debugPrint('Invalid image type: $imgType');
      return '';
    }
    String retUrl = '';
    String imgName = 'a.png';

    switch (imgType) {
      case 'coverart':
        final encodedSharanaCoverArtPath =
            Uri.encodeComponent('$sharanaCoverArtDir/$sharanaId/$imgName');

        retUrl = '$svsFSBucketBaseURL/$encodedSharanaCoverArtPath?alt=media';
        break;

      case 'mini':
        final encodedSharanaMiniImgPath =
            Uri.encodeComponent('$sharanaMiniImgDir/$sharanaId/$imgName');

        retUrl = '$svsFSBucketBaseURL/$encodedSharanaMiniImgPath?alt=media';
        break;
    }

    return retUrl;
  }

  static String getVachanaAudioTrackUrl(
      int sharanaId, String vachanaNameEnglish) {
    if (sharanaId <= 0 || vachanaNameEnglish.trim().isEmpty) return '';

    // Sanitize the vachana name for URL safety
    final cleanVachanaNameEnglish = vachanaNameEnglish
        .replaceAll(RegExp(r'[^\w\s-]'), '') // Remove special chars
        .replaceAll(RegExp(r'\s+'), '-')
        .trim()
        .toLowerCase();

    final encodedVachanaAudioTrackPath = Uri.encodeComponent(
        '$vachanaAudioTrackDir/$sharanaId/$cleanVachanaNameEnglish.mp3');

    return '$svsFSBucketBaseURL/$encodedVachanaAudioTrackPath?alt=media';
  }
}

class AppState extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _phoneNumber;
  List<Map<String, dynamic>> _allTracks = [];
  List<String> _favorites = [];
  List<Vachana> _allVachanas = [];

  bool get isLoggedIn => _isLoggedIn;
  String? get phoneNumber => _phoneNumber;
  List<Map<String, dynamic>> get allTracks => _allTracks;
  List<Vachana> get allVachanas => _allVachanas;
  List<String> get favorites => _favorites;

  Future<void> initialize() async {
    _isLoggedIn = false;
    _favorites = [];
    notifyListeners();
  }

  Future<void> login(String phone, String userId) async {
    _isLoggedIn = true;
    _phoneNumber = phone;
    notifyListeners();
  }

  Future<void> loadAllVachanas() async {
    if (_allVachanas.isNotEmpty) return;

    final snapshot =
        await FirebaseFirestore.instance.collection('colVachana').get();

    _allVachanas =
        snapshot.docs.map((doc) => Vachana.fromFirestore(doc)).toList();
    notifyListeners();
  }

  Future<void> refreshData() async {
    // Add your data refresh logic here
    // await loadSharanas();
    await loadAllVachanas();
    // Any other refresh operations
    notifyListeners();
  }
}
