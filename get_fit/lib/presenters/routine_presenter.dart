import '../models/routine_model.dart';
import '../models/workout_model.dart';

class RoutinePresenter {
  final List<Routine> _routines = [];
  final List<Workout> _availableWorkouts = [];

  List<Routine> get routines => List.unmodifiable(_routines);
  List<Workout> get availableWorkouts => List.unmodifiable(_availableWorkouts);
  List<String> get daysOfWeek => Routine.daysOfWeek;

  Future<void> loadRoutines() async {
    final loadedRoutines = await Routine.loadRoutines();
    final loadedWorkouts = await Workout.loadWorkouts();
    _routines
      ..clear()
      ..addAll(loadedRoutines);
    _availableWorkouts
      ..clear()
      ..addAll(loadedWorkouts);
  }

  Future<void> addRoutine({
    required String routineName,
    String? description,
  }) async {
    final trimmedName = routineName.trim();
    final trimmedDescription = description?.trim();
    if (trimmedName.isEmpty || trimmedName.length > 100) {
      throw ArgumentError('Routine name must be between 1 and 100 characters.');
    }

    final routine = Routine(
      routineName: trimmedName,
      description: trimmedDescription == null || trimmedDescription.isEmpty
          ? null
          : trimmedDescription,
    );
    final id = await routine.addRoutine(routine);
    _routines.add(
      Routine(
        id: id,
        routineName: routine.routineName,
        description: routine.description,
      ),
    );
  }

  Future<void> addWorkoutToRoutine({
    required String routineId,
    required String workoutId,
    required List<String> days,
  }) async {
    final routineIndex = _routines.indexWhere(
      (routine) => routine.id == routineId,
    );
    if (routineIndex == -1) {
      throw ArgumentError('Select a valid routine.');
    }
    final workoutIndex = _availableWorkouts.indexWhere(
      (workout) => workout.id == workoutId,
    );
    if (workoutIndex == -1) {
      throw ArgumentError('Select a valid workout.');
    }

    final selectedDays = days.toSet().toList()
      ..sort(
        (first, second) =>
            daysOfWeek.indexOf(first).compareTo(daysOfWeek.indexOf(second)),
      );
    if (selectedDays.isEmpty ||
        selectedDays.any((day) => !daysOfWeek.contains(day))) {
      throw ArgumentError('Select at least one valid day of the week.');
    }

    final routine = _routines[routineIndex];
    final workout = _availableWorkouts[workoutIndex];
    final assignment = RoutineWorkout(
      workoutId: workoutId,
      workoutName: workout.workoutName ?? 'Workout',
      days: selectedDays,
    );
    final nextWorkouts = [
      ...routine.workouts.where((existing) => existing.workoutId != workoutId),
      assignment,
    ];
    await routine.saveWorkouts(nextWorkouts);
    _routines[routineIndex] = Routine(
      id: routine.id,
      routineName: routine.routineName,
      description: routine.description,
      daysWorked: routine.daysWorked,
      workouts: nextWorkouts,
    );
  }

  Future<void> deleteRoutine(String routineId) async {
    final routine = _routines.firstWhere((routine) => routine.id == routineId);
    await routine.deleteRoutine(routineId);
    _routines.removeWhere((routine) => routine.id == routineId);
  }
}
