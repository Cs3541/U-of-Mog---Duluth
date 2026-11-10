import 'package:flutter/material.dart';
import '../models/friend_model.dart';
import '../presenters/friend_presenter.dart';
import 'friend_screen.dart';

String _joinNames(List<String> names) {
  if (names.isEmpty) return '';
  if (names.length == 1) return names.first;
  if (names.length == 2) return '${names[0]} and ${names[1]}';
  final others = names.length - 1;
  return '${names.first} and $others other${others == 1 ? '' : 's'}';
}

class PendingRequestsBanner extends StatelessWidget {
  const PendingRequestsBanner({super.key, required this.requests, this.onTap});

  final List<FriendRequest> requests;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final count = requests.length;
    return Card(
      color: Colors.amber.shade100,
      child: ListTile(
        leading: Badge(
          label: Text('$count'),
          child: const Icon(Icons.person_add, color: Colors.black87),
        ),
        title: Text(count == 1
            ? 'New friend request'
            : '$count new friend requests'),
        subtitle: Text(
            'From ${_joinNames(requests.map((r) => r.fromName).toList())}'),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class NewFriendsBanner extends StatelessWidget {
  const NewFriendsBanner({
    super.key,
    required this.friends,
    required this.onDismiss,
    this.onTap,
    this.dismissing = false,
  });

  final List<FriendUser> friends;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;
  final bool dismissing;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade100,
      child: ListTile(
        leading: const Icon(Icons.celebration, color: Colors.green),
        title: Text(friends.length == 1
            ? 'New friend'
            : '${friends.length} new friends'),
        subtitle: Text(
            'You\'re now friends with ${_joinNames(friends.map((f) => f.displayName).toList())}.'),
        trailing: dismissing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                tooltip: 'Dismiss',
                icon: const Icon(Icons.close),
                onPressed: onDismiss,
              ),
        onTap: onTap,
      ),
    );
  }
}

class FriendAlerts extends StatefulWidget {
  const FriendAlerts({super.key});

  @override
  State<FriendAlerts> createState() => _FriendAlertsState();
}

class _FriendAlertsState extends State<FriendAlerts> {
  final FriendsPresenter _presenter = FriendsPresenter();
  late final Stream<List<FriendRequest>> _incoming = _presenter.watchIncoming();
  late final Stream<List<FriendUser>> _newFriends = _presenter.watchNewFriends();
  bool _dismissing = false;

  void _openFriends() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FriendsScreen()),
    );
  }

  Future<void> _dismiss(List<FriendUser> friends) async {
    setState(() => _dismissing = true);
    final error = await _presenter.dismissNewFriends(friends);
    if (!mounted) return;
    setState(() => _dismissing = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StreamBuilder<List<FriendRequest>>(
          stream: _incoming,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('FriendAlerts: incoming failed: ${snapshot.error}');
            }
            final requests = snapshot.data ?? const <FriendRequest>[];
            if (requests.isEmpty) return const SizedBox.shrink();
            return PendingRequestsBanner(
              requests: requests,
              onTap: _openFriends,
            );
          },
        ),
        StreamBuilder<List<FriendUser>>(
          stream: _newFriends,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('FriendAlerts: new friends failed: ${snapshot.error}');
            }
            final friends = snapshot.data ?? const <FriendUser>[];
            if (friends.isEmpty) return const SizedBox.shrink();
            return NewFriendsBanner(
              friends: friends,
              dismissing: _dismissing,
              onDismiss: () => _dismiss(friends),
              onTap: _openFriends,
            );
          },
        ),
      ],
    );
  }
}