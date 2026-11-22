import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoggingModel {
  Future<ExerciseCatalog> loadCatalog() async {
    final document = await FirebaseFirestore.instance
        .collection('baseExercises')
        .doc('exercises')
        .get();
    final data = document.data() ?? <String, dynamic>{};
    final names = data.keys.toList();
    if (names.any((name) => name.trim().isEmpty || name.length > 100)) {
      throw StateError('Exercise names must contain 1–100 characters.');
    }
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final groups = <String, List<String>>{};
    for (final entry in data.entries) {
      if (entry.value is List) {
        groups[entry.key] = (entry.value as List).whereType<String>().toList();
      }
    }
    return ExerciseCatalog(names: names, muscleGroups: groups);
  }

  Future<List<String>> loadCommonExercises() async {
    return (await loadCatalog()).names;
  }

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
          if ((entry['exerciseName'] as String).trim().toLowerCase() !=
              exerciseName.trim().toLowerCase()) {
            continue;
          }
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

  Future<List<WorkoutHistoryEntry>> loadWorkoutHistory() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Please sign in first.');

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('workoutLogs')
        .orderBy('completedAt', descending: true)
        .get(const GetOptions(source: Source.server));
    final catalog = await loadCatalog();
    final history = <WorkoutHistoryEntry>[];

    for (final document in snapshot.docs) {
      final data = document.data();
      final rawExercises = data['exercises'];
      final entries = <Map<String, dynamic>>[];
      if (rawExercises is List) {
        entries.addAll(rawExercises.whereType<Map<String, dynamic>>());
      } else {
        final sets = await document.reference
            .collection('sets')
            .orderBy(FieldPath.documentId)
            .get(const GetOptions(source: Source.server));
        entries.addAll(sets.docs.map((set) => set.data()));
      }

      final exerciseLogs = <ExerciseLog>[];
      for (final entry in entries) {
        final name = entry['exerciseName'];
        final setCount = entry['sets'];
        final reps = entry['reps'];
        final weight = entry['weight'];
        if (name is! String ||
            setCount is! int ||
            reps is! int ||
            weight is! num) {
          continue;
        }
        for (
          var i = 0;
          i < setCount && exerciseLogs.length < maxWorkoutSets;
          i++
        ) {
          exerciseLogs.add(
            ExerciseLog(
              exerciseName: name,
              sets: 1,
              reps: reps,
              weight: weight.toDouble(),
            ),
          );
        }
      }

      final savedGroups = data['muscleGroups'];
      final groups = savedGroups is List
          ? savedGroups.whereType<String>().toSet()
          : <String>{
              for (final exercise in exerciseLogs)
                ..._groupsFor(catalog, exercise.exerciseName),
            };
      history.add(
        WorkoutHistoryEntry(
          id: document.id,
          workoutName: data['workoutName'] as String? ?? 'Workout',
          completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
          muscleGroups: groups.toList()..sort(),
          exercises: exerciseLogs,
        ),
      );
    }
    return history;
  }

  Future<String?> saveWorkout({
    String? workoutName,
    String? routineName,
    String? existingWorkoutId,
    required DateTime startedAt,
    required List<ExerciseLog> exercises,
    required List<String> muscleGroups,
  }) async {
    final user = _auth.currentUser;

    if (user == null) return 'Please sign in first.';
    if ((workoutName?.trim().length ?? 0) > 100 ||
        (routineName?.trim().isEmpty ?? false) ||
        (routineName?.trim().length ?? 0) > 100 ||
        exercises.isEmpty ||
        exercises.length > maxWorkoutSets) {
      return 'Add 1–$maxWorkoutSets sets and use names under 100 characters.';
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
      final workouts = firestore
          .collection('users')
          .doc(user.uid)
          .collection('workoutLogs');
      final workout = existingWorkoutId == null
          ? workouts.doc()
          : workouts.doc(existingWorkoutId);
      final name = workoutName?.trim().isNotEmpty == true
          ? workoutName!.trim()
          : _defaultWorkoutName(startedAt, exercises);
      final groups = muscleGroups.toSet().toList()..sort();
      final batch = firestore.batch();
      List<QueryDocumentSnapshot<Map<String, dynamic>>> oldSets = [];
      if (existingWorkoutId == null) {
        batch.set(workout, {
          'workoutName': name,
          'completedAt': FieldValue.serverTimestamp(),
          'weightUnit': 'lb',
          'setCount': exercises.length,
          'muscleGroups': groups,
        });
      } else {
        oldSets =
            (await workout
                    .collection('sets')
                    .orderBy(FieldPath.documentId)
                    .get())
                .docs;
        batch.update(workout, {
          'workoutName': name,
          'setCount': exercises.length,
          'muscleGroups': groups,
          'exercises': FieldValue.delete(),
        });
      }
      for (var i = 0; i < exercises.length; i++) {
        final exercise = exercises[i];
        final set = {
          'exerciseName': exercise.exerciseName.trim(),
          'sets': 1,
          'reps': exercise.reps,
          'weight': exercise.weight,
        };
        if (i < oldSets.length) {
          batch.set(oldSets[i].reference, set);
        } else {
          batch.set(
            workout.collection('sets').doc(i.toString().padLeft(3, '0')),
            set,
          );
        }
      }
      for (final set in oldSets.skip(exercises.length)) {
        batch.delete(set.reference);
      }
      if (routineName != null) {
        final routine = firestore
            .collection('users')
            .doc(user.uid)
            .collection('routines')
            .doc();
        batch.set(routine, {
          'routineName': routineName.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'muscleGroups': groups,
          'exercises': [
            for (final exercise in exercises)
              {
                'exerciseName': exercise.exerciseName.trim(),
                'sets': 1,
                'reps': exercise.reps,
                'weight': exercise.weight,
              },
          ],
        });
      }
      // Commit the workout and every set together, so a failed save leaves no partial workout.
      await batch.commit();

      return null;
    } on FirebaseException catch (error) {
      return error.message ?? 'Could not save workout.';
    }
  }

  Future<String?> deleteWorkout(String workoutId) async {
    final user = _auth.currentUser;
    if (user == null) return 'Please sign in first.';
    try {
      final workout = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('workoutLogs')
          .doc(workoutId);
      final sets = await workout.collection('sets').get();
      final batch = FirebaseFirestore.instance.batch();
      for (final set in sets.docs) {
        batch.delete(set.reference);
      }
      batch.delete(workout);
      await batch.commit();
      return null;
    } on FirebaseException catch (error) {
      return error.message ?? 'Could not delete workout.';
    }
  }

  String _defaultWorkoutName(DateTime date, List<ExerciseLog> exercises) {
    final dateText = '${date.month}/${date.day}/${date.year}';
    final names = <String>[];
    for (final exercise in exercises) {
      if (!names.contains(exercise.exerciseName))
        names.add(exercise.exerciseName);
      if (names.length == 2) break;
    }
    final suffix = names.join(' + ');
    final name = suffix.isEmpty ? 'Workout $dateText' : '$dateText • $suffix';
    return name.length <= 100 ? name : name.substring(0, 100);
  }

  static List<String> _groupsFor(ExerciseCatalog catalog, String exerciseName) {
    final name = exerciseName.trim().toLowerCase();
    for (final entry in catalog.muscleGroups.entries) {
      if (entry.key.trim().toLowerCase() == name) return entry.value;
    }
    return const [];
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

class ExerciseCatalog {
  const ExerciseCatalog({required this.names, required this.muscleGroups});

  final List<String> names;
  final Map<String, List<String>> muscleGroups;
}

class WorkoutHistoryEntry {
  const WorkoutHistoryEntry({
    required this.id,
    required this.workoutName,
    required this.completedAt,
    required this.muscleGroups,
    required this.exercises,
  });

  final String id;
  final String workoutName;
  final DateTime? completedAt;
  final List<String> muscleGroups;
  final List<ExerciseLog> exercises;
}

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
