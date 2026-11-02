import 'package:flutter/material.dart';
import '../models/exp_model.dart';
import '../presenters/auth_presenter.dart';
import '../presenters/exp_presenter.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  final AuthPresenter _presenter = AuthPresenter();
  final ExpPresenter _expPresenter = ExpPresenter();

  ProfileScreen({super.key});

  void _logout(BuildContext context) async {
    await _presenter.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = _presenter.getCurrentUserEmail() ?? 'Unknown User';
    final uid = _presenter.getCurrentUserId() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Email'),
                subtitle: Text(email),
              ),
            ),
            const SizedBox(height: 16),

            // NEW: level + EXP
            StreamBuilder<ExpStatus>(
              stream: _expPresenter.watchExp(uid),
              builder: (context, snapshot) {
                final s = snapshot.data;
                if (s == null) return const CircularProgressIndicator();
                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.star, color: Colors.amber),
                    title: Text('Level ${s.level}'),
                    subtitle: Text('${s.totalExp} EXP'),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.redAccent,
              ),
            )
          ],
        ),
      ),
    );
  }
}