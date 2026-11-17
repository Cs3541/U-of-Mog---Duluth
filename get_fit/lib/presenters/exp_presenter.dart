import 'package:firebase_auth/firebase_auth.dart';

import '../models/exp_model.dart';

class ExpPresenter {
  Stream<ExpStatus> watchExp(String uid) => ExpRules.watchExp(uid);

  Future<void> awardWorkout() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await ExpRules.addActivityExp(uid, 0);
  }
}