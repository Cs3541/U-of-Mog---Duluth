import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Workout {
  static const Map<String, List<String>> musclesByGroup = {
    'Chest': ['Pectorals', 'Upper chest', 'Lower chest'],
    'Back': ['Lats', 'Traps', 'Rhomboids', 'Lower back'],
    'Shoulders': ['Front delts', 'Side delts', 'Rear delts'],
    'Arms': ['Biceps', 'Triceps', 'Forearms'],
    'Legs': ['Quadriceps', 'Hamstrings', 'Glutes', 'Calves'],
    'Core': ['Abdominals', 'Obliques'],
    'Full Body': ['Full body'],
  };

  final String? id;
  final String? workoutName;
  final String? muscleGroup; //drop down menu for muscle group selection
  final String? muscle; //drop down menu for muscle selection

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
