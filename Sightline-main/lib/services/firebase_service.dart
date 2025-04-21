import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/document_model.dart';
import '../models/user_data.dart'; // Assuming UserData is defined in this file

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Register a user and store default preferences
  Future<UserCredential> registerUser(String email, String password) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = userCredential.user!.uid;

    await _firestore.collection('users').doc(uid).set({
      'email': email,
      'createdAt': Timestamp.now(),
      'lastLogin': Timestamp.now(),
      'preferences': {
        'darkMode': false,
        'notifications': true,
        'ttsSpeed': 1.0,
        'ttsPitch': 1.0,
        'ttsLanguage': 'en-US',
        'speakAsYouType': false,
        'pdfFontFamily': 'Arial',
        'pdfFontSize': 14,
        'pdfWordSpacing': 0.0,
        'pdfLetterSpacing': 0.0,
        'pdfLineSpacing': 1.0,
      },
    });

    return userCredential;
  }

  /// Sign in and update last login timestamp
  Future<UserCredential> signIn(String email, String password) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _firestore.collection('users').doc(userCredential.user!.uid).update({
      'lastLogin': Timestamp.now(),
    });

    return userCredential;
  }

  /// Sign out user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Get user preferences
  Future<Map<String, dynamic>?> getUserPreferences(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()?['preferences'];
  }

  /// Update entire preferences object
  Future<void> updateUserPreferences(
      String uid, Map<String, dynamic> newPrefs) async {
    await _firestore.collection('users').doc(uid).update({
      'preferences': newPrefs,
    });
  }

  /// Update only TTS preferences
  Future<void> updateTTSPreferences({
    required String uid,
    required double speed,
    required double pitch,
    required String language,
    required bool speakAsYouType,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'preferences.ttsSpeed': speed,
      'preferences.ttsPitch': pitch,
      'preferences.ttsLanguage': language,
      'preferences.speakAsYouType': speakAsYouType,
    });
  }

  /// Update only PDF preferences
  Future<void> updatePdfPreferences({
    required String uid,
    required String fontFamily,
    required double fontSize,
    required double wordSpacing,
    required double letterSpacing,
    required double lineSpacing,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'preferences.pdfFontFamily': fontFamily,
      'preferences.pdfFontSize': fontSize,
      'preferences.pdfWordSpacing': wordSpacing,
      'preferences.pdfLetterSpacing': letterSpacing,
      'preferences.pdfLineSpacing': lineSpacing,
    });
  }

  /// Change current password
  Future<void> changePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updatePassword(newPassword);
    }
  }

  /// Re-authenticate user and change password
  Future<void> reauthenticateAndChangePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('User not logged in');
    }

    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
  }

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Upload file to Firebase Storage and return download URL
  Future<String> uploadFileToStorage({
    required File file,
    required String path,
  }) async {
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  /// Save document metadata to Firestore
  Future<void> saveDocumentMetadata(DocumentModel doc) async {
    await _firestore.collection('documents').doc(doc.id).set(doc.toMap());
  }

  /// Get user profile from Firestore
  Future<UserData?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserData.fromMap(doc.data()!, uid);
  }

  FirebaseFirestore get firestore => _firestore;
}
