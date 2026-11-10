import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'badge_model.dart';
import 'feed_model.dart';
import 'profile_model.dart';

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
  static const int welcomeBonus = 5;

  static DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

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

  static int currentStreak(Map<String, dynamic> data) {
    final streak = (data['streakDays'] as num?)?.toInt() ?? 0;
    final lastDate = data['lastStreakDate'] as String?;
    final today = _dateKey(DateTime.now());
    final yesterday =
        _dateKey(DateTime.now().subtract(const Duration(days: 1)));
    if (lastDate != today && lastDate != yesterday) return 0;
    return streak;
  }

  static int bestStreak(Map<String, dynamic> data) {
    final best = (data['bestStreak'] as num?)?.toInt() ?? 0;
    final stored = (data['streakDays'] as num?)?.toInt() ?? 0;
    return max(best, stored);
  }

  static Future<void> addActivityExp(String uid, int durationMinutes) async {
    final ref = userDoc(uid);
    final feed = FeedRules.feedFor(uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      final data = snapshot.data() ?? {};

      final currentExp = (data['totalExp'] as num?)?.toInt() ?? 0;
      final lastDate = data['lastStreakDate'] as String?;
      final today = _dateKey(DateTime.now());
      final yesterday =
          _dateKey(DateTime.now().subtract(const Duration(days: 1)));

      final previousStreak = (data['streakDays'] as num?)?.toInt() ?? 0;
      int streak = previousStreak;
      int bonusDays = 0;
      if (lastDate != today) {
        streak = (lastDate == yesterday) ? streak + 1 : 1;
        bonusDays = streak;
      }

      final previousBest = bestStreak(data);
      final newBest = max(previousBest, streak);

      final gained = expForActivity(
        durationMinutes: durationMinutes,
        streakDays: bonusDays,
      );
      final newTotal = currentExp + gained;

      tx.set(
        ref,
        {
          'totalExp': newTotal,
          'streakDays': streak,
          'bestStreak': newBest,
          'lastStreakDate': today,
        },
        SetOptions(merge: true),
      );
      tx.set(
        ProfileRules.profileDoc(uid),
        {'totalExp': newTotal},
        SetOptions(merge: true),
      );

      if (gained > 0) {
        final streakBonus =
            min(streakBonusPerDay * bonusDays, maxStreakBonus);
        tx.set(
          feed.doc(),
          FeedRules.entry(
            type: FeedType.exp,
            title: '+$gained EXP',
            subtitle: streakBonus > 0
                ? '$durationMinutes min activity · includes +$streakBonus streak bonus'
                : '$durationMinutes min activity',
          ),
        );
      }

      final levelBefore = levelForExp(currentExp);
      final levelAfter = levelForExp(newTotal);
      if (levelAfter > levelBefore) {
        tx.set(
          feed.doc(),
          FeedRules.entry(
            type: FeedType.levelUp,
            title: 'Level $levelAfter reached!',
            subtitle: 'You leveled up from level $levelBefore.',
          ),
        );
      }

      final workouts = (data['workoutsCompleted'] as num?)?.toInt() ?? 0;
      final earned = BadgeRules.newlyEarned(
        before: {
          MilestoneType.workoutsCompleted: workouts,
          MilestoneType.streakDays: previousBest,
          MilestoneType.levelReached: levelBefore,
        },
        after: {
          MilestoneType.workoutsCompleted: workouts,
          MilestoneType.streakDays: newBest,
          MilestoneType.levelReached: levelAfter,
        },
      );
      for (final badge in earned) {
        tx.set(
          feed.doc(),
          FeedRules.entry(
            type: FeedType.badge,
            title: 'Badge earned: ${badge.name}',
            subtitle: badge.description,
          ),
        );
      }
    });
  }

  static const String _newUserCardId = 'new_user_badge';

  static Future<void> awardWelcomeBonus(String uid, {DateTime? joinedAt}) async {
    final ref = userDoc(uid);
    final feed = FeedRules.feedFor(uid);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      final data = snapshot.data() ?? {};

      final alreadyAwarded = data['welcomeBonusAwarded'] == true;
      final cardCreated = data['newUserCardCreated'] == true;
      if (alreadyAwarded && cardCreated) return;

      final updates = <String, dynamic>{};

      if (!alreadyAwarded) {
        final currentExp = (data['totalExp'] as num?)?.toInt() ?? 0;
        updates['totalExp'] = currentExp + welcomeBonus;
        tx.set(
          ProfileRules.profileDoc(uid),
          {'totalExp': currentExp + welcomeBonus},
          SetOptions(merge: true),
        );
        updates['welcomeBonusAwarded'] = true;
        updates['joinedAt'] = joinedAt != null
            ? Timestamp.fromDate(joinedAt)
            : FieldValue.serverTimestamp();

        tx.set(
          feed.doc(),
          FeedRules.entry(
            type: FeedType.exp,
            title: '+$welcomeBonus EXP',
            subtitle: 'Welcome bonus',
          ),
        );
      }

      if (!cardCreated) {
        final storedJoin = data['joinedAt'];
        final badgeTime =
            storedJoin is Timestamp ? storedJoin.toDate() : joinedAt;
        final badge = BadgeRules.allBadges
            .firstWhere((b) => b.type == MilestoneType.newUser);

        tx.set(
          feed.doc(_newUserCardId),
          FeedRules.entry(
            type: FeedType.badge,
            title: 'Badge earned: ${badge.name}',
            subtitle: badge.description,
            occurredAt: badgeTime,
            timeUnknown: alreadyAwarded && badgeTime == null,
          ),
        );
        updates['newUserCardCreated'] = true;
      }

      tx.set(ref, updates, SetOptions(merge: true));
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
    return userDoc(uid).snapshots().map((snapshot) {
      final data = snapshot.data() ?? {};
      final total = (data['totalExp'] as num?)?.toInt() ?? 0;
      return statusFor(total, currentStreak(data));
    });
  }
}