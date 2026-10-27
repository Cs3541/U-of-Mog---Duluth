import 'package:flutter/material.dart';
import '../presenters/auth_presenter.dart';
import 'login_screen.dart';
import 'main_navigation.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _presenter = AuthPresenter();

  String? _errorMessage;

  void _handleSignup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');

    if (!emailRegex.hasMatch(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }
    final error = await _presenter.signUp(
      _emailController.text.trim(),
      password,
    );
    if(error != null) {
      setState(() => _errorMessage = error);
    } else {
      // Navigate to the main navigation screen on successful signup
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red),),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _handleSignup,
              child: const Text('Sign Up'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text('Already have an account? Log in'),
            ),
          ],
        ),
      ),
    );
  }
}