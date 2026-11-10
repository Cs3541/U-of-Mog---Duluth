import 'package:firebase_auth/firebase_auth.dart';
import '../models/profile_model.dart';
import '../repositories/friend_repository.dart';

class LeaderboardPresenter {
  final FriendRepository _friends = FriendRepository();

  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<Profile>> watchLeaderboard() => ProfileRules.watchTopProfiles();

  Stream<Set<String>> watchFriendIds() {
    final uid = currentUid;
    if (uid == null) return Stream.value(<String>{});
    return _friends.watchFriendIds(uid);
  }

  List<Profile> friendsOnly(List<Profile> profiles, Set<String> friendIds) {
    if (friendIds.isEmpty) return [];
    return profiles
        .where((p) => friendIds.contains(p.uid) || p.uid == currentUid)
        .toList();
  }
}