import 'dart:math';
import 'package:firebase_database/firebase_database.dart';

class ExpAwardResult {
  final int expGained;

  const ExpAwardResult({
    required this.expGained,
  });
}

class ExpRules {
  static const int completionBonus = 15;
  static const int expPerMinute = 1;
  static const int maxExpPerActivity = 100;
  static const int expPerLevel = 100;

  static int expForActivity({ required int durationMinutes }) {
    if (durationMinutes <= 0) return 0;
    final raw = completionBonus + durationMinutes * expPerMinute;
    return min(raw.round(), maxExpPerActivity);
  }

  Future<void> addActivityExp(String uid, int durationMinutes) async {
    final ref = FirebaseDatabase.instance.ref('users/$uid/totalExp');
    final snapshot = await ref.get();
    final currentExp = (snapshot.value as int?) ?? 0;
    final gained = ExpRules.expForActivity(durationMinutes: durationMinutes);
    final newExp = currentExp + gained;
    await ref.set(newExp);
  }

  static int levelForExp(int totalExp) => totalExp ~/ expPerLevel + 1; // 100 exp per Level. (Simple 100 exp per level system for now)
}