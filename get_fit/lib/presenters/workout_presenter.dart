import '../models/workout_model.dart';

class WorkoutPresenter {
  final List<Workout> _workouts = [];

  List<Workout> get workouts => List.unmodifiable(_workouts);
  Map<String, List<String>> get musclesByGroup => Workout.musclesByGroup;

  Future<void> loadWorkouts() async {
    final loadedWorkouts = await Workout.loadWorkouts();
    _workouts.clear();
    _workouts.addAll(loadedWorkouts);
  }

  Future<void> addWorkout({
    required String workoutName,
    required String muscleGroup,
    required String muscle,
  }) async {
    final trimmedName = workoutName.trim();
    if (trimmedName.isEmpty || trimmedName.length > 100) {
      throw ArgumentError('Workout name must be between 1 and 100 characters.');
    }
    if (!Workout.musclesByGroup.containsKey(muscleGroup) ||
        !Workout.musclesByGroup[muscleGroup]!.contains(muscle)) {
      throw ArgumentError('Select a valid muscle group and muscle.');
    }

    final workout = Workout(
      workoutName: trimmedName,
      muscleGroup: muscleGroup,
      muscle: muscle,
    );
    final id = await Workout.addWorkout(workout);
    _workouts.add(
      Workout(
        id: id,
        workoutName: workout.workoutName,
        muscleGroup: workout.muscleGroup,
        muscle: workout.muscle,
      ),
    );
  }

  Future<void> deleteWorkout(String workoutId) async {
    await Workout.deleteWorkout(workoutId);
    _workouts.removeWhere((workout) => workout.id == workoutId);
  }
}
