import 'package:firebase_database/firebase_database.dart';

enum MilestoneType {
  workoutsCompleted,
  streakDays,
  levelReached,
}

class BadgeDefinition {
  final String id;
  final String name;
  final String description;
  final MilestoneType type;
  final int threshold;

  const BadgeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.threshold,
  });
}

class BadgeProgress {
  final String badgeId;
  final int currentProgress;
  final bool isAchieved;
  final DateTime? achievedAt;

  const BadgeProgress({
    required this.badgeId,
    required this.currentProgress,
    required this.isAchieved,
    this.achievedAt,
  });
}

class BadgeRules {
  static const List<BadgeDefinition> allBadges = [
    BadgeDefinition(
      id: 'first_workout',
      name: 'First Workout',
      description: 'Complete your first workout',
      type: MilestoneType.workoutsCompleted,
      threshold: 1,
    ),
    BadgeDefinition(
      id: 'ten_workouts',
      name: 'Ten Workouts',
      description: 'Complete 10 workouts',
      type: MilestoneType.workoutsCompleted,
      threshold: 10,
    ),
    BadgeDefinition(
      id: 'seven_day_streak',
      name: 'Seven Day Streak',
      description: 'Maintain a workout streak for 7 days',
      type: MilestoneType.streakDays,
      threshold: 7,
    ),
    BadgeDefinition(
      id: 'thirty_day_streak',
      name: 'Thirty Day Streak',
      description: 'Maintain a workout streak for 30 days',
      type: MilestoneType.streakDays,
      threshold: 30,
    ),
    BadgeDefinition(
      id: 'level_5',
      name: 'Level 5',
      description: 'Reach level 5',
      type: MilestoneType.levelReached,
      threshold: 5,
    ),
    BadgeDefinition(
      id: 'level_10',
      name: 'Level 10',
      description: 'Reach level 10',
      type: MilestoneType.levelReached,
      threshold: 10,
    ),
  ];

  static Future<List<BadgeDefinition>> updateBadgeProgress(String uid) async {
    final ref = FirebaseDatabase.instance.ref('users/$uid');
  }

  static Future<List<BadgeProgress>> getBadgeProgress(String uid) async {
    final ref = FirebaseDatabase.instance.ref('users/$uid/badges');
  }
}