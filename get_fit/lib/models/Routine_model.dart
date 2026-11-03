//imports
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class Routine{
  final String? id;
  final String? routineName;
  final String? description;
  final String? daysWorked;

  Routine({
    this.id,
    required this.routineName,
    this.description,
    this.daysWorked,
  });

  static Future<List<Routine>> loadRoutines() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final databaseRef = FirebaseDatabase.instance.ref();
    final routinesSnapshot = await databaseRef.child('routines').get();

    if (!routinesSnapshot.exists) {
      return [];
    }

    final routinesData = routinesSnapshot.value as Map<dynamic, dynamic>;
    final List<Routine> routines = [];

    routinesData.forEach((key, value) {
      final routineData = value as Map<dynamic, dynamic>;
      final routine = Routine(
        id: key,
        routineName: routineData['routineName'] as String?,
        description: routineData['description'] as String?,
        daysWorked: routineData['daysWorked'] as String?,
      );
      routines.add(routine);
    });

    return routines;
  }

  Future<void> addRoutine(Routine routine) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final databaseRef = FirebaseDatabase.instance.ref();
    final newRoutineRef = databaseRef.child('routines').push();
    await newRoutineRef.set({
      'routineName': routine.routineName,
      'description': routine.description,
      'daysWorked': routine.daysWorked,
    });
  }

  Future<void> deleteRoutine(String routineId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final databaseRef = FirebaseDatabase.instance.ref();
    await databaseRef.child('routines').child(routineId).remove();
  }
}