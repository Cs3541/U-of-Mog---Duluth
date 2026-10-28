import 'package:firebase_auth/firebase_auth.dart';

import '../models/auth_model.dart';

class AuthPresenter {
  final AuthModel _model = AuthModel();

  Future<String?> login(String email, String password) {
    return _model.login(email, password);
  }

  Future<String?> signUp(String email, String password) {
    return _model.signUp(email, password);
  }

  Future<void> logout() {
    return _model.signOut();
  }

  Stream authStateChanges() => _model.authStateChanges();

  String? getCurrentUserEmail() => _model.getCurrentUser()?.email;
}