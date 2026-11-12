import 'package:flutter/material.dart';
import '../models/badge_model.dart';
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
  late final Stream<FriendsOnly<Map<String, DateTime?>>> _badges =
      _presenter.watchBadges(widget.uid);
  late final Stream<FriendsOnly<DateTime?>> _lastWorkout =
      _presenter.watchLastWorkout(widget.uid);

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
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ProfileAvatar(photo: profile.photo, radius: 50),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: _LevelBadge(level: profile.level),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                profile.displayName,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              _buildLastWorkout(),
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
              const SizedBox(height: 16),
              _buildRecentBadges(),
              const SizedBox(height: 24),
              _buildActions(profile),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLastWorkout() {
    return StreamBuilder<FriendsOnly<DateTime?>>(
      stream: _lastWorkout,
      builder: (context, snapshot) {
        final visible = snapshot.data;
        if (visible == null || visible.hidden) return const SizedBox.shrink();
        final when = visible.value;
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fitness_center, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                when == null ? 'No workouts yet' : _formatLastWorkout(when),
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatLastWorkout(DateTime when) {
    final now = DateTime.now();
    final diff = now.difference(when);
    if (diff.inMinutes < 1) return 'Last workout just now';
    if (diff.inMinutes < 60) return 'Last workout ${diff.inMinutes} min ago';

    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(when.year, when.month, when.day);
    final days = today.difference(day).inDays;
    if (days == 0) return 'Last workout today';
    if (days == 1) return 'Last workout yesterday';
    if (days < 7) return 'Last workout $days days ago';

    final loc = MaterialLocalizations.of(context);
    return when.year == now.year
        ? 'Last workout ${loc.formatShortMonthDay(when)}'
        : 'Last workout ${loc.formatShortDate(when)}';
  }

  Widget _buildRecentBadges() {
    return StreamBuilder<FriendsOnly<Map<String, DateTime?>>>(
      stream: _badges,
      builder: (context, snapshot) {
        final visible = snapshot.data;
        if (visible == null) return const SizedBox.shrink();

        final earned = visible.value;
        if (visible.hidden || earned == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 18, color: Colors.grey),
                SizedBox(width: 6),
                Text(
                  'Badges and workouts are visible to friends',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        const slots = 3;
        final recent = BadgeRules.recent(earned, limit: slots);
        return Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Recent badges',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${earned.length} of ${BadgeRules.allBadges.length}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (recent.isEmpty)
                  const Text(
                    'No badges earned yet.',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final badge in recent)
                        Expanded(child: _BadgeTile(badge: badge)),
                      for (var i = recent.length; i < slots; i++)
                        const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
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

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.green,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'LVL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '$level',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});

  final BadgeDefinition badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          const Icon(Icons.emoji_events, size: 36, color: Colors.amber),
          const SizedBox(height: 4),
          Text(
            badge.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          Text(
            badge.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}