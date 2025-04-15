import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// **Sign Up Method**
  Future<String?> signUp({
    required String id,
    required String name,
    required String email,
    required String phone,
    required String role,
    String? flatId, // Optional for Committee Members
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Prepare user data
      Map<String, dynamic> userData = {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
      };

      // Add flatId only for Society Members
      if (role == 'Society Member' && flatId != null) {
        userData['flatId'] = flatId;
      }

      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(userData);

      return null; // Success, no error
    } catch (e) {
      return _handleAuthError(e);
    }
  }

  /// **Sign In Method**
  Future<String?> signIn(
      {required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // Success
    } catch (e) {
      return _handleAuthError(e);
    }
  }

  /// **Sign Out Method**
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// **Get Current User Data**
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return null;

      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      return userDoc.data() as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// **Reset Password**
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // Success
    } catch (e) {
      return _handleAuthError(e);
    }
  }

  /// **Error Handling Helper**
  String _handleAuthError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return "This email is already registered.";
        case 'invalid-email':
          return "Invalid email format.";
        case 'weak-password':
          return "Password is too weak.";
        case 'user-not-found':
          return "No user found with this email.";
        case 'wrong-password':
          return "Incorrect password.";
        case 'too-many-requests':
          return "Too many login attempts. Try again later.";
        default:
          return "Authentication error: ${e.message}";
      }
    }
    return "An unknown error occurred.";
  }
}
