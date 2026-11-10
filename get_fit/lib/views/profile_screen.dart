import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/exp_model.dart';
import '../models/profile_model.dart';
import '../presenters/auth_presenter.dart';
import '../presenters/exp_presenter.dart';
import '../presenters/profile_presenter.dart';
import 'login_screen.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.photo, this.radius = 20});

  final Uint8List? photo;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bytes = photo;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.deepPurple,
      backgroundImage: bytes != null ? MemoryImage(bytes) : null,
      child: bytes == null
          ? Icon(Icons.person, size: radius, color: Colors.white)
          : null,
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthPresenter _presenter = AuthPresenter();
  final ExpPresenter _expPresenter = ExpPresenter();
  final ProfilePresenter _profilePresenter = ProfilePresenter();
  final TextEditingController _nameController = TextEditingController();

  late final String _email = _presenter.getCurrentUserEmail() ?? 'Unknown User';
  late final String _uid = _presenter.getCurrentUserId() ?? '';
  late final Stream<Profile>? _profileStream =
      _uid.isEmpty ? null : _profilePresenter.watchProfile(_uid);
  late final Stream<ExpStatus>? _expStream =
      _uid.isEmpty ? null : _expPresenter.watchExp(_uid);

  bool _nameLoaded = false;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await _presenter.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _run(Future<String?> Function() action, [String? success]) async {
    setState(() => _busy = true);
    final error = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    final message = error ?? success;
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          _buildProfileSection(),
          const SizedBox(height: 24),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email'),
              subtitle: Text(_email),
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<ExpStatus>(
            stream: _expStream,
            builder: (context, snapshot) {
              final s = snapshot.data;
              if (s == null) {
                return const Center(child: CircularProgressIndicator());
              }
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
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return StreamBuilder<Profile>(
      stream: _profileStream,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        if (profile != null && !_nameLoaded) {
          _nameLoaded = true;
          _nameController.text = profile.displayName;
        }

        return Column(
          children: [
            ProfileAvatar(photo: profile?.photo, radius: 50),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy || profile == null
                      ? null
                      : () => _run(() => _profilePresenter.takePhoto(_uid)),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Take photo'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy || profile == null
                      ? null
                      : () => _run(() => _profilePresenter.uploadPhoto(_uid)),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Upload photo'),
                ),
                if (profile?.photo != null)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() => _profilePresenter.removePhoto(_uid)),
                    child: const Text('Remove photo'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    maxLength: ProfileRules.maxNameLength,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: FilledButton(
                    onPressed: _busy || profile == null
                        ? null
                        : () => _run(
                              () => _profilePresenter.saveDisplayName(
                                  _uid, _nameController.text),
                              'Display name saved.',
                            ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}