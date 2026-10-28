import 'dart:math';
import 'package:firebase_database/firebase_database.dart';

class ExpAwardResult {
  final int expGained;
  final int streakDays;

  const ExpAwardResult({
    required this.expGained,
    required this.streakDays,
  });
}

class ExpRules {
  static const int completionBonus = 15;
  static const int expPerMinute = 1;
  static const int maxExpPerActivity = 100;
  static const int expPerLevel = 100;
  static const int streakBonusPerDay = 5;
  static const int maxStreakBonus = 150;

  static int expForActivity({
    required int durationMinutes,
    required int streakDays
  }) {
    if (durationMinutes <= 0) return 0;
    final raw = completionBonus + durationMinutes * expPerMinute;
    final capped = min(raw, maxExpPerActivity);
    final bonus = min(streakBonusPerDay * streakDays, maxStreakBonus);
    return capped + bonus;
  }

  static Future<void> addActivityExp(String uid, int durationMinutes) async {
    final ref = FirebaseDatabase.instance.ref('users/$uid');
    final snapshot = await ref.get();
    final data = (snapshot.value as Map?) ?? {};
    final currentExp = (data['totalExp'] as int?) ?? 0;
    final lastDate = data['lastStreakDate'] as String?;
    final today = DateTime.now().toString().substring(0, 10);
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toString()
        .substring(0, 10);
    int streak = (data['streakDays'] as int?) ?? 0;
    int bonusDays = 0;
    if (lastDate != today) {
      streak = (lastDate == yesterday) ? streak + 1 : 1;
      bonusDays = streak;
    }

    final gained = expForActivity(
      durationMinutes: durationMinutes,
      streakDays: bonusDays,
    );

    await ref.update({
      'totalExp': currentExp + gained,
      'streakDays': streak,
      'lastStreakDate': today,
    });
  }

  static int levelForExp(int totalExp) => totalExp ~/ expPerLevel + 1; // 100 exp per Level. (Simple 100 exp per level system for now)
}