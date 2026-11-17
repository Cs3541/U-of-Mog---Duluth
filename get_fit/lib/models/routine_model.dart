import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoutineWorkout {
  RoutineWorkout({
    required this.workoutId,
    required this.workoutName,
    required List<String> days,
  }) : days = List.unmodifiable(days);

  final String workoutId;
  final String workoutName;
  final List<String> days;

  Map<String, dynamic> toMap() => {
    'workoutId': workoutId,
    'workoutName': workoutName,
    'days': days,
  };

  factory RoutineWorkout.fromMap(Map<String, dynamic> data) {
    final rawDays = data['days'];
    return RoutineWorkout(
      workoutId: data['workoutId'] as String? ?? '',
      workoutName: data['workoutName'] as String? ?? 'Workout',
      days: rawDays is List
          ? rawDays.whereType<String>().toList()
          : const <String>[],
    );
  }
}

class Routine {
  static const List<String> daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final String? id;
  final String? routineName;
  final String? description;
  final String? daysWorked;
  final List<RoutineWorkout> workouts;

  Routine({
    this.id,
    required this.routineName,
    this.description,
    this.daysWorked,
    List<RoutineWorkout> workouts = const [],
  }) : workouts = List.unmodifiable(workouts);

  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('routines');

  static void _requireUser() {
    if (FirebaseAuth.instance.currentUser == null) {
      throw Exception('User not authenticated');
    }
  }

  static Future<List<Routine>> loadRoutines() async {
    _requireUser();

    final snapshot = await _col.get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final rawWorkouts = data['workouts'];
      final workouts = rawWorkouts is List
          ? rawWorkouts
                .whereType<Map<String, dynamic>>()
                .map(RoutineWorkout.fromMap)
                .where((workout) => workout.workoutId.isNotEmpty)
                .toList()
          : const <RoutineWorkout>[];

      return Routine(
        id: doc.id,
        routineName: data['routineName'] as String?,
        description: data['description'] as String?,
        daysWorked: data['daysWorked'] as String?,
        workouts: workouts,
      );
    }).toList();
  }

  Future<String> addRoutine(Routine routine) async {
    _requireUser();

    final docRef = await _col.add({
      'routineName': routine.routineName,
      'description': routine.description,
      'daysWorked': routine.daysWorked,
      'workouts': routine.workouts.map((workout) => workout.toMap()).toList(),
    });
    return docRef.id;
  }

  Future<void> saveWorkouts(List<RoutineWorkout> workouts) async {
    _requireUser();
    final routineId = id;
    if (routineId == null) {
      throw StateError('Cannot update a routine without an ID.');
    }
    await _col.doc(routineId).update({
      'workouts': workouts.map((workout) => workout.toMap()).toList(),
    });
  }

  Future<void> deleteRoutine(String routineId) async {
    _requireUser();
    await _col.doc(routineId).delete();
  }
}
