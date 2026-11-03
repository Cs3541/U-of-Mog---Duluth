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

class ExpStatus {
  final int totalExp;
  final int level;
  final int expIntoLevel;
  final int expToNextLevel;
  final int streakDays;

  const ExpStatus({
    required this.totalExp,
    required this.level,
    required this.expIntoLevel,
    required this.expToNextLevel,
    required this.streakDays,
  });

  double get progress =>
      expToNextLevel == 0 ? 0 : expIntoLevel / expToNextLevel;
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
    required int streakDays,
  }) {
    if (durationMinutes <= 0) return 0;
    final raw = completionBonus + durationMinutes * expPerMinute;
    final capped = min(raw, maxExpPerActivity);
    final bonus = min(streakBonusPerDay * streakDays, maxStreakBonus);
    return capped + bonus;
  }

  static String _dateKey(DateTime d) => d.toString().substring(0, 10);

  static Future<void> addActivityExp(String uid, int durationMinutes) async {
    final ref = FirebaseDatabase.instance.ref('users/$uid');
    final snapshot = await ref.get();
    final data = (snapshot.value as Map?) ?? {};
    final currentExp = (data['totalExp'] as num?)?.toInt() ?? 0;
    final lastDate = data['lastStreakDate'] as String?;
    final today = _dateKey(DateTime.now());
    final yesterday =
        _dateKey(DateTime.now().subtract(const Duration(days: 1)));
    int streak = (data['streakDays'] as num?)?.toInt() ?? 0;
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

  static int totalExpForLevel(int level) =>
      expPerLevel * level * (level - 1) ~/ 2;

  static int levelForExp(int totalExp) {
    if (totalExp <= 0) return 1;
    return ((1 + sqrt(1 + 8 * totalExp / expPerLevel)) / 2).floor();
  }

  static ExpStatus statusFor(int totalExp, int streakDays) {
    final level = levelForExp(totalExp);
    final levelStart = totalExpForLevel(level);
    final levelEnd = totalExpForLevel(level + 1);
    return ExpStatus(
      totalExp: totalExp,
      level: level,
      expIntoLevel: totalExp - levelStart,
      expToNextLevel: levelEnd - levelStart,
      streakDays: streakDays,
    );
  }

  static Stream<ExpStatus> watchExp(String uid) {
    return FirebaseDatabase.instance.ref('users/$uid').onValue.map((event) {
      final data = (event.snapshot.value as Map?) ?? {};
      final total = (data['totalExp'] as num?)?.toInt() ?? 0;
      int streak = (data['streakDays'] as num?)?.toInt() ?? 0;
      final lastDate = data['lastStreakDate'] as String?;
      final today = _dateKey(DateTime.now());
      final yesterday = _dateKey(DateTime.now().subtract(const Duration(days: 1)));
      if (lastDate != today && lastDate != yesterday) streak = 0;

      return statusFor(total, streak);
    });
  }
}