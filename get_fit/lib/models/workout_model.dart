import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('workouts');

  static void _requireUser() {
    if (FirebaseAuth.instance.currentUser == null) {
      throw Exception('User not authenticated');
    }
  }

  static Future<List<Workout>> loadWorkouts() async {
    _requireUser();

    final snapshot = await _col.get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Workout(
        id: doc.id,
        workoutName: data['workoutName'] as String?,
        muscleGroup: data['muscleGroup'] as String?,
        muscle: data['muscle'] as String?,
      );
    }).toList();
  }

  /// Saves the workout and returns the new document's id.
  static Future<String> addWorkout(Workout workout) async {
    _requireUser();

    final docRef = await _col.add({
      'workoutName': workout.workoutName,
      'muscleGroup': workout.muscleGroup,
      'muscle': workout.muscle,
    });
    return docRef.id;
  }

  static Future<void> deleteWorkout(String workoutId) async {
    _requireUser();
    await _col.doc(workoutId).delete();
  }
}