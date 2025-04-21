import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../models/user_data.dart';

class RegistrationResult {
  final UserData? userData;
  final String? error;

  RegistrationResult({this.userData, this.error});
}

class RegistrationController {
  final FirebaseService _firebaseService = FirebaseService();

  // Password validation
  bool _isPasswordValid(String password) {
    return password.length >= 6 && 
           password.contains(RegExp(r'[A-Z]')) &&  // At least one uppercase
           password.contains(RegExp(r'[0-9]'));    // At least one number
  }

  Future<RegistrationResult> registerUser(String email, String password) async {
    try {
      // Validate email format
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        return RegistrationResult(error: 'Please enter a valid email address.');
      }

      // Validate password requirements
      if (!_isPasswordValid(password)) {
        return RegistrationResult(
          error: 'Password must be at least 6 characters long and contain at least one uppercase letter and one number.',
        );
      }

      // Attempt registration
      final userCredential = await _firebaseService.registerUser(email, password);
      final uid = userCredential.user!.uid;

      // Get user profile with preferences
      final userData = await _firebaseService.getUserProfile(uid);
      if (userData == null) {
        throw Exception('Failed to initialize user profile');
      }

      return RegistrationResult(userData: userData);
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email address is already registered. Please use a different email or try signing in.';
          break;
        case 'invalid-email':
          message = 'The email address format is not valid. Please check and try again.';
          break;
        case 'operation-not-allowed':
          message = 'Email/password registration is not enabled. Please contact support.';
          break;
        case 'weak-password':
          message = 'The password is too weak. Please use a stronger password with at least 6 characters.';
          break;
        default:
          message = 'Registration failed: ${e.message ?? 'Unknown error occurred'}';
      }
      return RegistrationResult(error: message);
    } catch (e) {
      return RegistrationResult(
        error: 'An unexpected error occurred during registration. Please try again later.',
      );
    }
  }
}
