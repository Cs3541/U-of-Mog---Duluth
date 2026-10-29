// add imports eventually


class Workout {
  final String? id;
  final String? workoutName;
  final String? muscle;
  final String? muscleGroup;
  final String? description;

  Workout({
    this.id,
    required this.workoutName,
    required this.muscle,
    required this.muscleGroup,
    this.description,
  });
}