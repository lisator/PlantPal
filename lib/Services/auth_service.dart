import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get user => _auth.authStateChanges();

  Future<User?> signUpWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(
        e.message ?? 'Unable to create account.',
      );
    }
  }

  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final UserCredential credential =
          await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(
        e.message ?? 'Unable to sign in.',
      );
    }
  }

  Future<void> sendPasswordResetEmail(
    String email,
  ) async {
    try {
      await _auth.sendPasswordResetEmail(
        email: email.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(
        '${e.code}: ${e.message ?? 'Unable to send password reset email.'}',
      );
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}