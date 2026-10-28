import 'dart:math';

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

  static int expForActivity({ required int durationMinutes }) {
    if (durationMinutes <= 0) return 0;
    final raw = completionBonus + durationMinutes * expPerMinute;
    return min(raw.round(), maxExpPerActivity);
  }
}