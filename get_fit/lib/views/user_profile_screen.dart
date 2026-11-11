import 'package:flutter/material.dart';
import '../models/profile_model.dart';
import '../presenters/user_profile_presenter.dart';
import 'profile_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.uid, this.initialName});

  final String uid;
  final String? initialName;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final UserProfilePresenter _presenter = UserProfilePresenter();
  late final Stream<Profile> _profile = _presenter.watchProfile(widget.uid);
  late final Stream<Relationship> _relationship =
      _presenter.watchRelationship(widget.uid);

  bool _busy = false;

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

  Future<void> _confirmRemove(Profile profile) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${profile.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove == true && mounted) {
      _run(
        () => _presenter.removeFriend(profile.uid),
        'Removed ${profile.displayName} from friends.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialName ?? 'Profile'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<Profile>(
        stream: _profile,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load this profile.'));
          }
          final profile = snapshot.data;
          if (profile == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(child: ProfileAvatar(photo: profile.photo, radius: 50)),
              const SizedBox(height: 12),
              Text(
                profile.displayName,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.star, color: Colors.amber),
                  title: Text('Level ${profile.level}'),
                  subtitle: Text('${profile.totalExp} EXP'),
                ),
              ),
              const SizedBox(height: 24),
              _buildActions(profile),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActions(Profile profile) {
    return StreamBuilder<Relationship>(
      stream: _relationship,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Could not load friend status.',
            textAlign: TextAlign.center,
          );
        }
        final rel = snapshot.data;
        if (rel == null || _busy) {
          return const Center(child: CircularProgressIndicator());
        }

        return switch (rel.status) {
          FriendStatus.self => const Text(
              'This is how others see your profile.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          FriendStatus.friends => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _StatusLabel(
                  icon: Icons.check_circle,
                  color: Colors.green,
                  text: 'Friends',
                ),
                OutlinedButton.icon(
                  onPressed: () => _confirmRemove(profile),
                  icon: const Icon(Icons.person_remove),
                  label: const Text('Remove friend'),
                ),
              ],
            ),
          FriendStatus.requestReceived => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusLabel(
                  icon: Icons.person_add,
                  color: Colors.amber.shade800,
                  text: '${profile.displayName} sent you a friend request',
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _run(() => _presenter.decline(rel.request!)),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _run(
                          () => _presenter.accept(rel.request!),
                          'You\'re now friends with ${profile.displayName}.',
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          FriendStatus.requestSent => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _StatusLabel(
                  icon: Icons.schedule,
                  color: Colors.grey,
                  text: 'Friend request sent',
                ),
                OutlinedButton(
                  onPressed: () => _run(
                    () => _presenter.cancel(rel.request!),
                    'Friend request canceled.',
                  ),
                  child: const Text('Cancel request'),
                ),
              ],
            ),
          FriendStatus.none => FilledButton.icon(
              onPressed: () => _run(
                () => _presenter.sendRequest(profile),
                'Friend request sent.',
              ),
              icon: const Icon(Icons.person_add),
              label: const Text('Add friend'),
            ),
        };
      },
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}