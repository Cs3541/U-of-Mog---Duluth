import 'package:flutter/material.dart';
import '../models/profile_model.dart';
import '../presenters/leaderboard_presenter.dart';
import 'profile_screen.dart';
import 'user_profile_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final LeaderboardPresenter _presenter = LeaderboardPresenter();
  late final Stream<List<Profile>> _stream = _presenter.watchLeaderboard();
  late final Stream<Set<String>> _friendIds = _presenter.watchFriendIds();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green,
            tabs: [Tab(text: 'Global'), Tab(text: 'Friends')],
          ),
          Expanded(
            child: StreamBuilder<List<Profile>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Could not load the leaderboard.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final profiles = snapshot.data!;
                return StreamBuilder<Set<String>>(
                  stream: _friendIds,
                  builder: (context, friendSnap) {
                    final friendIds = friendSnap.data ?? <String>{};
                    return TabBarView(
                      children: [
                        _buildList(profiles, 'No one is on the leaderboard yet.'),
                        _buildList(
                          _presenter.friendsOnly(profiles, friendIds),
                          'No friends yet. Add friends from your Profile.',
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Profile> profiles, String emptyText) {
    if (profiles.isEmpty) {
      return Center(child: Text(emptyText));
    }
    return ListView.builder(
      itemCount: profiles.length,
      itemBuilder: (context, i) {
        final profile = profiles[i];
        final isMe = profile.uid == _presenter.currentUid;
        final rowColor = isMe
            ? Colors.green.shade100
            : (i.isEven ? Colors.white : Colors.grey.shade200);

        return Container(
          color: rowColor,
          child: ListTile(
            leading: SizedBox(
              width: 80,
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ProfileAvatar(photo: profile.photo),
                ],
              ),
            ),
            title: Text(
              isMe ? '${profile.displayName} (You)' : profile.displayName,
              style: TextStyle(
                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: _buildLevelBadge(profile.level),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(
                  uid: profile.uid,
                  initialName: profile.displayName,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLevelBadge(int level) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: Colors.green,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'LVL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '$level',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}