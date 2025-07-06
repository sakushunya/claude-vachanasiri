// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<User?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      return userCredential.user;
    } catch (e) {
      print("Anonymous sign-in failed: $e");
      return null;
    }
  }

  static Future<String?> getIdToken() async {
    try {
      return await _auth.currentUser?.getIdToken();
    } catch (e) {
      print("Token retrieval failed: $e");
      return null;
    }
  }

  // In auth_service.dart
  static Future<void> ensureAuthenticated() async {
    // print("Current user before auth: ${_auth.currentUser?.uid}");
    if (_auth.currentUser == null) {
      print("No user found - signing in anonymously");
      await signInAnonymously();
      print("New user: ${_auth.currentUser?.uid}");
    } else {
      // print("User already authenticated: ${_auth.currentUser?.uid}");
    }
  }
}
