import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Routine {
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
      return Routine(
        id: doc.id,
        routineName: data['routineName'] as String?,
        description: data['description'] as String?,
        daysWorked: data['daysWorked'] as String?,
      );
    }).toList();
  }

  Future<String> addRoutine(Routine routine) async {
    _requireUser();

    final docRef = await _col.add({
      'routineName': routine.routineName,
      'description': routine.description,
      'daysWorked': routine.daysWorked,
    });
    return docRef.id;
  }

  Future<void> deleteRoutine(String routineId) async {
    _requireUser();
    await _col.doc(routineId).delete();
  }
}