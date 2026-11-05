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

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> saveWorkout(
    String workoutName,
    List<ExerciseLog> exercises,
  ) async {
    final user = _auth.currentUser;

    if (user == null) return 'Please sign in first.';
    if (workoutName.trim().isEmpty || exercises.isEmpty) {
      return 'Enter a workout name and at least one exercise.';
    }

    for (final exercise in exercises) {
      if (exercise.exerciseName.trim().isEmpty ||
          exercise.sets <= 0 ||
          exercise.reps <= 0 ||
          !exercise.weight.isFinite ||
          exercise.weight < 0) {
        return 'Each exercise needs a name, positive sets and reps, '
            'and a weight of 0 or more.';
      }
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('workoutLogs')
          .add({
            'workoutName': workoutName.trim(),
            'completedAt': FieldValue.serverTimestamp(),
            'weightUnit': 'lb',
            'exercises': exercises
                .map(
                  (exercise) => {
                    'exerciseName': exercise.exerciseName.trim(),
                    'sets': exercise.sets,
                    'reps': exercise.reps,
                    'weight': exercise.weight,
                  },
                )
                .toList(),
          });

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

// Data for one exercise entry; saving and the logging screen come later.
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
