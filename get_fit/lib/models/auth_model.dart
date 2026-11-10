import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_model.dart';

class AuthModel {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signUp(
    String email,
    String password,
    String displayName,
  ) async {
    final nameError = ProfileRules.validateName(displayName);
    if (nameError != null) return nameError;

    final UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      return e.toString();
    }

    final user = credential.user!;
    final name = displayName.trim();
    try {
      await user.updateDisplayName(name);
      await ProfileRules.profileDoc(user.uid).set(
        {'displayName': name},
        SetOptions(merge: true),
      );
    } catch (_) {}
    return null;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? getCurrentUser() => _auth.currentUser;
}