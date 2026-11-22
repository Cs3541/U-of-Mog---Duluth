import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/exercise_model.dart';

class WorkoutSet {
  WorkoutSet({this.reps = '', this.weight = '', this.completed = false});

  String reps;
  String weight;
  bool completed;

  WorkoutSet.fromLog(ExerciseLog log, {this.completed = false})
    : reps = log.reps.toString(),
      weight = log.weight.toString();

  String? get error {
    final count = int.tryParse(reps.trim());
    final load = double.tryParse(weight.trim());
    if (count == null ||
        count < 1 ||
        count > 1000 ||
        load == null ||
        !load.isFinite ||
        load < 0 ||
        load > 10000) {
      return 'Enter 1–1000 reps and 0–10000 lb. Use 0 for bodyweight.';
    }
    return null;
  }

  ExerciseLog toLog(String name) => ExerciseLog(
    exerciseName: name,
    sets: 1,
    reps: int.parse(reps.trim()),
    weight: double.parse(weight.trim()),
  );
}

class WorkoutExercise {
  WorkoutExercise(this.name, {bool empty = true}) {
    if (!empty) sets.clear();
  }
  final String name;
  final sets = [WorkoutSet()];
  List<ExerciseLog> previous = [];
  bool loadingPrevious = true;
  String? historyError;
}

class LoggingPresenter {
  LoggingPresenter({
    LoggingModel? model,
    List<ExerciseLog> initialExercises = const [],
    List<bool> initialCompleted = const [],
    List<Map<String, dynamic>> initialDraft = const [],
    DateTime? startedAt,
    this.existingWorkoutId,
    this.workoutName,
  }) : _model = model ?? LoggingModel(),
       startedAt = startedAt ?? DateTime.now() {
    if (initialDraft.isNotEmpty) {
      for (final entry in initialDraft) {
        final name = entry['exerciseName'];
        if (name is! String) continue;
        final matching = exercises.where((item) => item.name == name);
        WorkoutExercise? exercise = matching.isEmpty ? null : matching.first;
        if (exercise == null) {
          exercise = WorkoutExercise(name, empty: false);
          exercises.add(exercise);
        }
        exercise.sets.add(
          WorkoutSet(
            reps: entry['reps']?.toString() ?? '',
            weight: entry['weight']?.toString() ?? '',
            completed: entry['completed'] == true,
          ),
        );
      }
    } else {
      for (var index = 0; index < initialExercises.length; index++) {
        final log = initialExercises[index];
        final existing = exercises.where(
          (item) => item.name == log.exerciseName,
        );
        final exercise = existing.isEmpty
            ? WorkoutExercise(log.exerciseName, empty: false)
            : existing.first;
        if (existing.isEmpty) exercises.add(exercise);
        exercise.sets.add(
          WorkoutSet.fromLog(
            log,
            completed:
                existingWorkoutId != null ||
                (index < initialCompleted.length && initialCompleted[index]),
          ),
        );
      }
    }
  }

  final LoggingModel _model;
  final exercises = <WorkoutExercise>[];
  final DateTime startedAt;
  final String? existingWorkoutId;
  final String? workoutName;
  ExerciseCatalog? catalog;
  Set<String> get muscleGroups => {
    for (final exercise in exercises)
      if (catalog != null) ..._groupsFor(catalog!, exercise.name),
  };
  int get setCount =>
      exercises.fold(0, (count, exercise) => count + exercise.sets.length);
  bool get canAddSet => setCount < LoggingModel.maxWorkoutSets;

  Future<List<String>> loadCommonExercises() async {
    catalog = await _model.loadCatalog();
    return catalog!.names;
  }

  List<String> _groupsFor(ExerciseCatalog catalog, String exerciseName) {
    final name = exerciseName.trim().toLowerCase();
    for (final entry in catalog.muscleGroups.entries) {
      if (entry.key.trim().toLowerCase() == name) return entry.value;
    }
    return const [];
  }

  Future<void> loadPrevious(WorkoutExercise exercise) async {
    try {
      exercise.previous = await _model.previousSets(exercise.name);
    } catch (_) {
      exercise.historyError =
          'Previous numbers unavailable. You can still log sets.';
    } finally {
      exercise.loadingPrevious = false;
    }
  }

  Future<String?> save({String? workoutName, String? routineName}) async {
    if (setCount == 0) return 'Add at least one exercise and complete a set.';
    if (setCount > LoggingModel.maxWorkoutSets) {
      return 'Use up to ${LoggingModel.maxWorkoutSets} sets per workout.';
    }
    for (final exercise in exercises) {
      for (final set in exercise.sets) {
        if (set.error != null) return '${exercise.name}: ${set.error}';
        if (!set.completed) {
          return 'Check off each finished set, or remove unfinished sets.';
        }
      }
    }
    return _model.saveWorkout(
      workoutName: workoutName,
      routineName: routineName,
      existingWorkoutId: existingWorkoutId,
      startedAt: startedAt,
      muscleGroups: muscleGroups.toList(),
      exercises: [
        for (final exercise in exercises)
          for (final set in exercise.sets) set.toLog(exercise.name),
      ],
    );
  }

  Future<String?> deleteWorkout(String workoutId) =>
      _model.deleteWorkout(workoutId);

  Future<void> saveDraft({String? workoutName}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final preferences = await SharedPreferences.getInstance();
    final key = _draftKey(user.uid);
    if (exercises.isEmpty) {
      await preferences.remove(key);
      return;
    }
    await preferences.setString(
      key,
      jsonEncode({
        'startedAt': startedAt.toIso8601String(),
        'workoutName': workoutName ?? this.workoutName,
        'existingWorkoutId': existingWorkoutId,
        'exercises': [
          for (final exercise in exercises)
            for (final set in exercise.sets)
              {
                'exerciseName': exercise.name,
                'reps': set.reps,
                'weight': set.weight,
                'completed': set.completed,
              },
        ],
      }),
    );
  }

  static String _draftKey(String uid) => 'active_workout_draft_$uid';

  static Future<Map<String, dynamic>?> loadDraft() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final preferences = await SharedPreferences.getInstance();
    final key = _draftKey(user.uid);
    final text = preferences.getString(key);
    if (text == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(text) as Map);
    } on FormatException {
      await preferences.remove(key);
      return null;
    } on TypeError {
      await preferences.remove(key);
      return null;
    }
  }

  static Future<void> clearDraft() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_draftKey(user.uid));
  }
}
