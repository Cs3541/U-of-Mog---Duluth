import '../models/exercise_model.dart';

class LoggingPresenter {
  LoggingPresenter({LoggingModel? model}) : _model = model ?? LoggingModel();
  final LoggingModel _model;
  final List<ExerciseLog> exercises = [];

  String? addExercise(String name, String sets, String reps, String weight) {
    if (exercises.length >= 10) {
      return 'A workout can contain up to 10 exercises.';
    }
    final setCount = int.tryParse(sets.trim());
    final repCount = int.tryParse(reps.trim());
    final load = double.tryParse(weight.trim());
    if (!LoggingModel.commonExercises.contains(name) ||
        setCount == null ||
        setCount < 1 ||
        setCount > 100 ||
        repCount == null ||
        repCount < 1 ||
        repCount > 1000 ||
        load == null ||
        !load.isFinite ||
        load < 0 ||
        load > 10000) {
      return 'Use 1–100 sets, 1–1000 reps, and a weight from 0–10000 lb.';
    }
    exercises.add(
      ExerciseLog(
        exerciseName: name,
        sets: setCount,
        reps: repCount,
        weight: load,
      ),
    );
    return null;
  }

  Future<String?> save(String name) async {
    final error = await _model.saveWorkout(name, List.of(exercises));
    if (error == null) exercises.clear();
    return error;
  }
}
