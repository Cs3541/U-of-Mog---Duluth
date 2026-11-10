import '../models/workout_model.dart';

class WorkoutPresenter {
  final List<Workout> _workouts = [];

  List<Workout> get workouts => List.unmodifiable(_workouts);

  Future<void> loadWorkouts() async {
    final loadedWorkouts = await Workout.loadWorkouts();
    _workouts.clear();
    _workouts.addAll(loadedWorkouts);
  }

  Future<void> addWorkout({
    required String workoutName,
    String? muscleGroup,
    String? muscle,
  }) async {
    final workout = Workout(
      workoutName: workoutName,
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
