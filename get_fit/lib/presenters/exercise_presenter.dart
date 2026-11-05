class ExercisePresenter {
	ExercisePresenter({
		required this.name,
		this.description = '',
		this.durationMinutes = 0,
		this.calories = 0,
	});

	final String name;
	final String description;
	final int durationMinutes;
	final int calories;

	String get title => name;

	String get durationLabel => '$durationMinutes min';

	String get caloriesLabel => '$calories kcal';

	bool get hasDescription => description.trim().isNotEmpty;
}
