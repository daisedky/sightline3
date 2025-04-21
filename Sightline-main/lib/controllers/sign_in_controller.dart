import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_data.dart';
import '../services/firebase_service.dart';

class SignInResult {
  final UserData? userData;
  final String? error;

  SignInResult({this.userData, this.error});
}

class SignInController {
  final FirebaseService _firebaseService = FirebaseService();

  Future<SignInResult> signIn(String email, String password) async {
    try {
      final credential = await _firebaseService.signIn(email, password);
      final uid = credential.user!.uid;
      final userData = await _firebaseService.getUserProfile(uid);
      return SignInResult(userData: userData);
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found for that email.';
          break;
        case 'wrong-password':
          message = 'Incorrect password.';
          break;
        case 'invalid-email':
          message = 'Invalid email address.';
          break;
        default:
          message = 'Login failed. Please try again.';
      }
      return SignInResult(error: message);
    } catch (e) {
      return SignInResult(error: 'Unexpected error occurred.');
    }
  }
}
