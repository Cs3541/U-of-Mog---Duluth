import 'package:firebase_auth/firebase_auth.dart';

import '../models/exp_model.dart';

class ExpPresenter {
  Stream<ExpStatus> watchExp(String uid) => ExpRules.watchExp(uid);

  Future<void> awardWorkout(int minutes) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await ExpRules.addActivityExp(uid, minutes < 1 ? 1 : minutes);
  }
}