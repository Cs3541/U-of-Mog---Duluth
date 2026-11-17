import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WeeklyVolume {
  const WeeklyVolume({required this.volume, required this.workoutCount});

  final double volume;
  final int workoutCount;
}

class ProgressModel {
  static const weeksToShow = 5;

  Stream<List<WeeklyVolume>> watchWeeklyVolume() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream<List<WeeklyVolume>>.error(
        StateError('Please sign in first.'),
      );
    }

    final now = DateTime.now();
    final thisWeek = _weekStart(now);
    final firstWeek = thisWeek.subtract(
      const Duration(days: 7 * (weeksToShow - 1)),
    );
    final logs = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('workoutLogs')
        .where(
          'completedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(firstWeek),
          isLessThan: Timestamp.fromDate(
            thisWeek.add(const Duration(days: 7)),
          ),
        )
        .orderBy('completedAt');

    return logs.snapshots().asyncMap((snapshot) async {
      final volumes = List<double>.filled(weeksToShow, 0);
      final workoutCounts = List<int>.filled(weeksToShow, 0);
      for (final workout in snapshot.docs) {
        final completedAt = workout.data()['completedAt'];
        if (completedAt is! Timestamp) continue;

        final weekIndex =
            _weekStart(completedAt.toDate()).difference(firstWeek).inDays ~/ 7;
        if (weekIndex < 0 || weekIndex >= weeksToShow) continue;
        workoutCounts[weekIndex]++;
        volumes[weekIndex] += await _workoutVolume(workout);
      }
      return [
        for (var index = 0; index < weeksToShow; index++)
          WeeklyVolume(
            volume: volumes[index],
            workoutCount: workoutCounts[index],
          ),
      ];
    });
  }

  DateTime _weekStart(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  Future<double> _workoutVolume(
    QueryDocumentSnapshot<Map<String, dynamic>> workout,
  ) async {
    final data = workout.data();
    final List entries;
    if (data['exercises'] is List) {
      entries = data['exercises'] as List;
    } else {
      final sets = await workout.reference
          .collection('sets')
          .get(const GetOptions(source: Source.server));
      entries = sets.docs.map((set) => set.data()).toList();
    }

    var volume = 0.0;
    for (final entry in entries) {
      if (entry is! Map) continue;
      final weight = entry['weight'];
      final reps = entry['reps'];
      final sets = entry['sets'];
      if (weight is! num || reps is! num) continue;
      final setCount = sets is num ? sets.toInt() : 1;
      if (!weight.isFinite ||
          !reps.isFinite ||
          weight < 0 ||
          weight > 10000 ||
          reps < 1 ||
          reps > 1000 ||
          setCount < 1 ||
          setCount > 100) {
        continue;
      }
      volume += weight.toDouble() * reps * setCount;
    }
    return volume;
  }
}
