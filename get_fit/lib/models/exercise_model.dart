import 'package:firebase_auth/firebase_auth.dart';

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

  // Log an exercise session with a specific exercise name and duration
  Future<String?> logExercise(String exerciseName, int duration) async {
    try {
      // Here you would typically send the exercise data to your backend or database
      // For demonstration purposes, we'll just print it to the console
      print('Logged exercise: $exerciseName for $duration minutes');
      return null;
    } catch (e) {
      return e.toString();
    }
  }
  
}

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
