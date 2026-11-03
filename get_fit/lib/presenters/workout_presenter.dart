import '../models/workout_model.dart';

class WorkoutPresenter {
  final List<Workout> _workouts = [];

  List<Workout> get workouts => _workouts;

  Future<void> loadWorkouts() async {
    final loadedWorkouts = await Workout.loadWorkouts();
    _workouts.clear();
    _workouts.addAll(loadedWorkouts);
  }

  Future<void> addWorkout(Workout workout) async {
    await Workout.addWorkout(workout);
    _workouts.add(workout);
  }

  Future<void> deleteWorkout(String workoutId) async {
    await Workout.deleteWorkout(workoutId);
    _workouts.removeWhere((workout) => workout.id == workoutId);
  }
}