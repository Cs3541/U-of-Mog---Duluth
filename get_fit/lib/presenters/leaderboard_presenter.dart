import 'package:firebase_auth/firebase_auth.dart';
import '../models/profile_model.dart';

class LeaderboardPresenter {
  final List<String> friendIds = [];

  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<Profile>> watchLeaderboard() => ProfileRules.watchTopProfiles();

  List<Profile> friendsOnly(List<Profile> profiles) =>
      profiles.where((p) => friendIds.contains(p.uid)).toList();
}