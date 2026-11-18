import 'package:firebase_auth/firebase_auth.dart';
import '../models/badge_model.dart';

class BadgePresenter {
  List<BadgeDefinition> get allBadges => BadgeRules.allBadges;

  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  Future<List<BadgeProgress>> getBadgeProgress() async {
    final uid = currentUid;
    if (uid == null) return [];
    return BadgeRules.getBadgeProgress(uid);
  }
}