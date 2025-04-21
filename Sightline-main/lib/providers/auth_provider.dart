import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../models/user_data.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  UserData? _currentUser;
  String? _error;
  bool _loading = false;

  UserData? get currentUser => _currentUser;
  String? get error => _error;
  bool get isLoading => _loading;
  bool get isAuthenticated => _firebaseService.currentUserId != null;

  // Initialize user on app start
  Future<void> initializeUser() async {
    final uid = _firebaseService.currentUserId;
    if (uid != null) {
      _currentUser = await _firebaseService.getUserProfile(uid);
      notifyListeners();
    }
  }

  // Register user
  Future<bool> register(String email, String password) async {
    try {
      _loading = true;
      _error = null;
      notifyListeners();

      final cred = await _firebaseService.registerUser(email, password);
      _currentUser = await _firebaseService.getUserProfile(cred.user!.uid);

      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Login user
  Future<bool> login(String email, String password) async {
    try {
      _loading = true;
      _error = null;
      notifyListeners();

      final cred = await _firebaseService.signIn(email, password);
      _currentUser = await _firebaseService.getUserProfile(cred.user!.uid);

      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Logout
  Future<void> logout() async {
    await _firebaseService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  /// Update dark mode preference
  Future<void> setDarkMode(bool isDark) async {
    if (_currentUser == null) return;
    final newPrefs = {..._currentUser!.preferences, 'darkMode': isDark};

    await _firebaseService.updateUserPreferences(_currentUser!.uid, newPrefs);

    _currentUser = UserData(
      uid: _currentUser!.uid,
      email: _currentUser!.email,
      createdAt: _currentUser!.createdAt,
      lastLogin: _currentUser!.lastLogin,
      preferences: newPrefs,
    );
    notifyListeners();
  }

  /// Update TTS Preferences
  Future<void> setTTSPreferences({
    required double speed,
    required double pitch,
    required String language,
    required bool speakAsYouType,
  }) async {
    if (_currentUser == null) return;

    await _firebaseService.updateTTSPreferences(
      uid: _currentUser!.uid,
      speed: speed,
      pitch: pitch,
      language: language,
      speakAsYouType: speakAsYouType,
    );

    final updated = {
      ..._currentUser!.preferences,
      'ttsSpeed': speed,
      'ttsPitch': pitch,
      'ttsLanguage': language,
      'speakAsYouType': speakAsYouType,
    };

    _currentUser = _currentUser!.copyWith(preferences: updated);
    notifyListeners();
  }

  /// Update PDF font preferences
  Future<void> setPDFPreferences({
    required String fontFamily,
    required double fontSize,
    required double wordSpacing,
    required double letterSpacing,
    required double lineSpacing,
  }) async {
    if (_currentUser == null) return;

    await _firebaseService.updatePdfPreferences(
      uid: _currentUser!.uid,
      fontFamily: fontFamily,
      fontSize: fontSize,
      wordSpacing: wordSpacing,
      letterSpacing: letterSpacing,
      lineSpacing: lineSpacing,
    );

    final updated = {
      ..._currentUser!.preferences,
      'pdfFontFamily': fontFamily,
      'pdfFontSize': fontSize,
      'pdfWordSpacing': wordSpacing,
      'pdfLetterSpacing': letterSpacing,
      'pdfLineSpacing': lineSpacing,
    };

    _currentUser = _currentUser!.copyWith(preferences: updated);
    notifyListeners();
  }
}
