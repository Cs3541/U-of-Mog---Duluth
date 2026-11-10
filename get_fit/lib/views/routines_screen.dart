import 'package:flutter/material.dart';
import '../models/routine_model.dart';

/// Browse routines and add workouts with a weekly schedule.
class RoutinesScreen extends StatefulWidget {
	const RoutinesScreen({
		super.key,
		required this.routines,
		required this.createRoutine,
		required this.onRoutineAdded,
		required this.onWorkoutAdded,
	});

	final List<RoutineModel> routines;
	final RoutineModel Function(String name) createRoutine;
	final ValueChanged<RoutineModel> onRoutineAdded;
	final void Function(RoutineModel routine, String workoutName, Set<int> days)
			onWorkoutAdded;

	@override
	State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class RoutineModel {
}

class _RoutinesScreenState extends State<RoutinesScreen> {
	RoutineModel? _selected;
	static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

	String _name(RoutineModel routine) {
		try {
			return ((routine as dynamic).name ?? 'Routine').toString();
		} catch (_) {
			return 'Routine';
		}
	}

	List<dynamic> _workouts(RoutineModel routine) {
		try {
			final value = (routine as dynamic).workouts;
			return value is Iterable ? value.toList() : const [];
		} catch (_) {
			return const [];
		}
	}

	String _workoutName(dynamic workout) {
		try {
			return (workout.name ?? workout.title ?? workout).toString();
		} catch (_) {
			return workout.toString();
		}
	}

	String _days(dynamic workout) {
		try {
			final days = workout.daysOfWeek ?? workout.days;
			if (days is Iterable) {
				return days.map((value) {
					final index = value is int ? value : int.tryParse('$value');
					return index != null && index >= 1 && index <= 7
							? _weekdays[index - 1]
							: '$value';
				}).join(', ');
			}
		} catch (_) {}
		return 'No days scheduled';
	}

	Future<String?> _textDialog(String title, String hint) async {
		final controller = TextEditingController();
		final result = await showDialog<String>(
			context: context,
			builder: (context) => AlertDialog(
				title: Text(title),
				content: TextField(
					controller: controller,
					autofocus: true,
					decoration: InputDecoration(hintText: hint),
					onSubmitted: (value) => Navigator.pop(context, value),
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
					FilledButton(
						onPressed: () => Navigator.pop(context, controller.text),
						child: const Text('Save'),
					),
				],
			),
		);
		controller.dispose();
		return result;
	}

	Future<void> _createRoutine() async {
		final name = await _textDialog('New routine', 'Routine name');
		if (!mounted || name == null || name.trim().isEmpty) return;
		final routine = widget.createRoutine(name.trim());
		widget.onRoutineAdded(routine);
		setState(() => _selected = routine);
	}

	Future<void> _createWorkout(RoutineModel routine) async {
		final name = await _textDialog('Add workout', 'Workout name');
		if (!mounted || name == null || name.trim().isEmpty) return;
		final days = await showDialog<Set<int>>(
			context: context,
			builder: (_) => const _WeekdayDialog(),
		);
		if (days == null || !mounted) return;
		widget.onWorkoutAdded(routine, name.trim(), days);
		setState(() {});
	}

	@override
	Widget build(BuildContext context) {
		final routines = widget.routines;
		final routine = _selected != null && routines.contains(_selected)
				? _selected!
				: routines.isNotEmpty
						? routines.first
						: null;
		if (_selected != routine) _selected = routine;

		return Scaffold(
			appBar: AppBar(title: const Text('Routines')),
			floatingActionButton: FloatingActionButton.extended(
				onPressed: _createRoutine,
				icon: const Icon(Icons.add),
				label: const Text('New routine'),
			),
			body: routines.isEmpty
					? const Center(child: Text('No routines yet. Create one to get started.'))
					: Column(
							children: [
								SizedBox(
									height: 68,
									child: ListView.separated(
										padding: const EdgeInsets.all(12),
										scrollDirection: Axis.horizontal,
										itemCount: routines.length,
										separatorBuilder: (_, __) => const SizedBox(width: 8),
										itemBuilder: (context, index) {
											final item = routines[index];
											return ChoiceChip(
												label: Text(_name(item)),
												selected: item == routine,
												onSelected: (_) => setState(() => _selected = item),
											);
										},
									),
								),
								const Divider(height: 1),
								if (routine != null) Expanded(child: _routineContents(routine)),
							],
						),
		);
	}

	Widget _routineContents(RoutineModel routine) {
		final workouts = _workouts(routine);
		return ListView(
			padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
			children: [
				Text(_name(routine), style: Theme.of(context).textTheme.headlineSmall),
				const SizedBox(height: 8),
				Text('${workouts.length} ${workouts.length == 1 ? 'workout' : 'workouts'}'),
				const SizedBox(height: 12),
				if (workouts.isEmpty)
					const Padding(
						padding: EdgeInsets.symmetric(vertical: 24),
						child: Center(child: Text('No workouts in this routine yet.')),
					)
				else
					...workouts.map((workout) => Card(
								child: ListTile(
									leading: const CircleAvatar(child: Icon(Icons.fitness_center)),
									title: Text(_workoutName(workout)),
									subtitle: Text(_days(workout)),
								),
							)),
				OutlinedButton.icon(
					onPressed: () => _createWorkout(routine),
					icon: const Icon(Icons.add),
					label: const Text('Add workout'),
				),
			],
		);
	}
}

class _WeekdayDialog extends StatefulWidget {
	const _WeekdayDialog();

	@override
	State<_WeekdayDialog> createState() => _WeekdayDialogState();
}

class _WeekdayDialogState extends State<_WeekdayDialog> {
	static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
	final Set<int> _selected = {};

	@override
	Widget build(BuildContext context) => AlertDialog(
				title: const Text('Select workout days'),
				content: Wrap(
					spacing: 6,
					children: List.generate(_days.length, (index) {
						final day = index + 1;
						return FilterChip(
							label: Text(_days[index]),
							selected: _selected.contains(day),
							onSelected: (selected) => setState(() {
								if (selected) {
									_selected.add(day);
								} else {
									_selected.remove(day);
								}
							}),
						);
					}),
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
					FilledButton(
						onPressed: () => Navigator.pop(context, Set<int>.from(_selected)),
						child: const Text('Done'),
					),
				],
			);
}
