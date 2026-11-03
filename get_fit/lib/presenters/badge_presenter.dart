import 'package:firebase_auth/firebase_auth.dart';
import '../models/badge_model.dart';

class BadgePresenter {
  List<BadgeDefinition> get allBadges => BadgeRules.allBadges;

  Future<List<BadgeProgress>> getBadgeProgress() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return BadgeRules.getBadgeProgress(uid);
  }
}