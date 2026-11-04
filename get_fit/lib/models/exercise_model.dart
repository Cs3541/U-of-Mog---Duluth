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
    try {
      print('Logged exercise: $exerciseName for $duration minutes');
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

// Data for one exercise entry; logging screen later
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
