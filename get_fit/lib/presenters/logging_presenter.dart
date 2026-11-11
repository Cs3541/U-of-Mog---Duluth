import '../models/exercise_model.dart';

class WorkoutSet {
  String reps = '';
  String weight = '';
  bool completed = false;

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
  WorkoutExercise(this.name);
  final String name;
  final sets = [WorkoutSet()];
  List<ExerciseLog> previous = [];
  bool loadingPrevious = true;
  String? historyError;
}

class LoggingPresenter {
  LoggingPresenter({LoggingModel? model}) : _model = model ?? LoggingModel();
  final LoggingModel _model;
  final exercises = <WorkoutExercise>[];
  final startedAt = DateTime.now();
  int get setCount =>
      exercises.fold(0, (count, exercise) => count + exercise.sets.length);
  bool get canAddSet => setCount < LoggingModel.maxWorkoutSets;

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

  Future<String?> save({String? workoutName}) async {
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
    final date = startedAt
        .toIso8601String()
        .substring(0, 16)
        .replaceFirst('T', ' ');
    return _model.saveWorkout(workoutName ?? 'Workout $date', [
      for (final exercise in exercises)
        for (final set in exercise.sets) set.toLog(exercise.name),
    ]);
  }
}
