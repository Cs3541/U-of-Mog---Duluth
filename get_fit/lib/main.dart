import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'views/main_navigation.dart';
import 'views/login_screen.dart';
import 'models/exp_model.dart';
import 'models/profile_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user == null) return;
    try {
      await ExpRules.awardWelcomeBonus(
        user.uid,
        joinedAt: user.metadata.creationTime,
      );
    } catch (e) {
      debugPrint('Could not award welcome bonus: $e');
    }
    try {
      await ProfileRules.ensureProfile(
        user.uid,
        displayName: user.displayName,
      );
    } catch (e) {
      debugPrint('Could not set up profile: $e');
    }
  });

  runApp(const GetFitApp());
}

class GetFitApp extends StatelessWidget {
  const GetFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Get Fit',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.deepPurple,
            body: Center(
              child: Text(
                'Get Fit!',
                style: TextStyle(
                  fontSize: 28,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }
        if (snapshot.hasData) {
          return const MainNavigation();
        }
        return const LoginScreen();
      },
    );
  }
}