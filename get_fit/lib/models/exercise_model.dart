import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoggingModel {
  static const commonExercises = [
    'Bench Press',
    'Squat',
    'Deadlift',
    'Overhead Press',
    'Barbell Row',
    'Pull-up',
    'Push-up',
    'Biceps Curl',
  ];

  static const maxWorkoutSets = 100;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<List<ExerciseLog>> previousSets(String exerciseName) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Please sign in first.');
    final query = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('workoutLogs')
        .orderBy('completedAt', descending: true)
        .limit(20);
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      final page =
          await (cursor == null ? query : query.startAfterDocument(cursor)).get(
            const GetOptions(source: Source.server),
          );
      for (final document in page.docs) {
        final matches = <ExerciseLog>[];
        final List entries;
        if (document.data().containsKey('exercises')) {
          entries = document.data()['exercises'] as List;
        } else {
          final sets = await document.reference
              .collection('sets')
              .orderBy(FieldPath.documentId)
              .get(const GetOptions(source: Source.server));
          entries = sets.docs.map((set) => set.data()).toList();
        }
        for (final entry in entries) {
          if (entry['exerciseName'] != exerciseName) continue;
          // Older workouts stored several identical sets in one entry.
          for (var i = 0; i < (entry['sets'] as int); i++) {
            if (matches.length == maxWorkoutSets) break;
            matches.add(
              ExerciseLog(
                exerciseName: exerciseName,
                sets: 1,
                reps: entry['reps'] as int,
                weight: (entry['weight'] as num).toDouble(),
              ),
            );
          }
        }
        if (matches.isNotEmpty) return matches;
      }
      if (page.docs.length < 20) return [];
      cursor = page.docs.last;
    }
  }

  Future<String?> saveWorkout(
    String workoutName,
    List<ExerciseLog> exercises,
  ) async {
    final user = _auth.currentUser;

    if (user == null) return 'Please sign in first.';
    if (workoutName.trim().isEmpty ||
        workoutName.trim().length > 100 ||
        exercises.isEmpty ||
        exercises.length > maxWorkoutSets) {
      return 'A workout needs a label and 1–$maxWorkoutSets set entries.';
    }

    for (final exercise in exercises) {
      if (exercise.exerciseName.trim().isEmpty ||
          exercise.exerciseName.trim().length > 100 ||
          exercise.sets != 1 ||
          exercise.reps <= 0 ||
          exercise.reps > 1000 ||
          !exercise.weight.isFinite ||
          exercise.weight < 0 ||
          exercise.weight > 10000) {
        return 'Log each set separately with 1–1000 reps and 0–10000 lb.';
      }
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final workout = firestore
          .collection('users')
          .doc(user.uid)
          .collection('workoutLogs')
          .doc();
      final batch = firestore.batch();
      batch.set(workout, {
        'workoutName': workoutName.trim(),
        'completedAt': FieldValue.serverTimestamp(),
        'weightUnit': 'lb',
        'setCount': exercises.length,
      });
      for (var i = 0; i < exercises.length; i++) {
        final exercise = exercises[i];
        batch.set(
          workout.collection('sets').doc(i.toString().padLeft(3, '0')),
          {
            'exerciseName': exercise.exerciseName.trim(),
            'sets': 1,
            'reps': exercise.reps,
            'weight': exercise.weight,
          },
        );
      }
      // Commit the workout and every set together, so a failed save leaves no partial workout.
      await batch.commit();

      return null; // No error: Firebase accepted the save.
    } on FirebaseException catch (error) {
      return error.message ?? 'Could not save workout.';
    }
  }

  // Log an exercise session with a specific exercise name and duration
  Future<String?> logExercise(String exerciseName, int duration) async {
    // Make sure the user is logged in before logging the exercise
    final user = _auth.currentUser;
    if (user == null) {
      return 'User not logged in';
    }
    // Save the exercise log to the user's account in Firestore (or any other storage solution)
    try {
      print('Logged exercise: $exerciseName for $duration minutes');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('exerciseLogs')
          .add({
            'exerciseName': exerciseName,
            'duration': duration,
            'loggedAt': FieldValue.serverTimestamp(),
          });
      return null;
    } on FirebaseException catch (error) {
      return error.message ?? 'Failed to save exercise log';
    }
  }
}

// Data for one exercise entry; logging screen later
/// Stopwatch that can be started, paused, resumed, and reset.
class DurationTimer {
  final Stopwatch _stopwatch = Stopwatch();

  bool get isRunning => _stopwatch.isRunning;
  int get elapsedSeconds => _stopwatch.elapsed.inSeconds;

  void start() => _stopwatch.start();

  void pause() => _stopwatch.stop();

  /// Stops the timer and returns the total elapsed time in seconds.
  int stop() {
    _stopwatch.stop();
    return elapsedSeconds;
  }

  void reset() {
    _stopwatch
      ..stop()
      ..reset();
  }
}

/// Optional timer for one exercise; finishing it saves the duration as a log.
class ExerciseTimer extends DurationTimer {
  final String exerciseName;

  ExerciseTimer(this.exerciseName);

  Future<String?> finishAndLog(LoggingModel loggingModel) {
    return loggingModel.logExercise(exerciseName, stop());
  }
}

/// Optional timer for tracking an entire workout.
class WorkoutTimer extends DurationTimer {}

// Each new entry is one set. Older saved entries may group identical sets.
class ExerciseLog {
  final String exerciseName;
  final int sets;
  final int reps;
  final double weight; // Pounds; 0 for bodyweight exercises.

  ExerciseLog({
    required this.exerciseName,
    required this.sets,
    required this.reps,
    required this.weight,
  });
}
