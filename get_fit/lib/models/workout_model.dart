import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class Workout {
  final String? id;
  final String? workoutName;
  final String? muscleGroup;
  final String? muscle;

  Workout({
    this.id,
    required this.workoutName,
    required this.muscleGroup,
    required this.muscle,
  });

  static Future<List<Workout>> loadWorkouts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final databaseRef = FirebaseDatabase.instance.ref();
    final workoutsSnapshot = await databaseRef.child('workouts').get();

    if (!workoutsSnapshot.exists) {
      return [];
    }

    final workoutsData = workoutsSnapshot.value as Map<dynamic, dynamic>;
    final List<Workout> workouts = [];

    workoutsData.forEach((key, value) {
      final workoutData = value as Map<dynamic, dynamic>;
      final workout = Workout(
        id: key,
        workoutName: workoutData['workoutName'] as String?,
        muscleGroup: workoutData['muscleGroup'] as String?,
        muscle: workoutData['muscle'] as String?,
      );
      workouts.add(workout);
    });

    return workouts;
  }

  static Future<void> addWorkout(Workout workout) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final databaseRef = FirebaseDatabase.instance.ref();
    final newWorkoutRef = databaseRef.child('workouts').push();
    await newWorkoutRef.set({
      'workoutName': workout.workoutName,
      'muscleGroup': workout.muscleGroup,
      'muscle': workout.muscle,
    });
  }

  static Future<void> deleteWorkout(String workoutId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final databaseRef = FirebaseDatabase.instance.ref();
    await databaseRef.child('workouts/$workoutId').remove();
  }
}