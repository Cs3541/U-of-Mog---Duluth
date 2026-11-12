import 'package:flutter/material.dart';
import '../models/workout_model.dart';
import '../presenters/workout_presenter.dart';
import 'routine_screen.dart';
import 'workout_logging_screen.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  final WorkoutPresenter _presenter = WorkoutPresenter();
  Workout? _selectedWorkout;
  bool _isLoading = true;
  bool _isOpening = false;
  String? _loadError;
  final Set<String> _deletingWorkoutIds = {};

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    try {
      await _presenter.loadWorkouts();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = null;
        if (!_presenter.workouts.any(
          (workout) => workout.id == _selectedWorkout?.id,
        )) {
          _selectedWorkout = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _addWorkout() async {
    final details =
        await showDialog<({String name, String muscleGroup, String muscle})>(
          context: context,
          builder: (_) =>
              _AddWorkoutDialog(musclesByGroup: _presenter.musclesByGroup),
        );

    if (details == null || !mounted) return;

    try {
      await _presenter.addWorkout(
        workoutName: details.name,
        muscleGroup: details.muscleGroup,
        muscle: details.muscle,
      );
      if (!mounted) return;
      setState(() {
        _selectedWorkout = _presenter.workouts.last;
        _loadError = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Workout added.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add workout: $error')));
    }
  }

  Future<void> _logSelectedWorkout() async {
    final workout = _selectedWorkout;
    if (workout == null || _isOpening) return;

    setState(() => _isOpening = true);
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkoutLoggingScreen(
          workoutName: workout.workoutName,
          muscleGroup: workout.muscleGroup,
          muscle: workout.muscle,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _isOpening = false);
    if (result == true) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Workout logged.')));
    }
  }

  Future<void> _deleteWorkout(Workout workout) async {
    final workoutId = workout.id;
    if (workoutId == null || _deletingWorkoutIds.contains(workoutId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete workout?'),
        content: Text(
          'Delete "${workout.workoutName ?? 'Workout'}" from your workouts?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingWorkoutIds.add(workoutId));
    try {
      await _presenter.deleteWorkout(workoutId);
      if (!mounted) return;
      setState(() {
        _deletingWorkoutIds.remove(workoutId);
        if (_selectedWorkout?.id == workoutId) _selectedWorkout = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Workout deleted.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _deletingWorkoutIds.remove(workoutId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete workout: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green,
            tabs: [
              Tab(text: 'Workouts'),
              Tab(text: 'Routines'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [_buildWorkoutsContent(), const RoutineScreen()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutsContent() {
    final workouts = _presenter.workouts;
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _loadError != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Could not load workouts: $_loadError'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _loadError = null;
                      });
                      _loadWorkouts();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Choose a workout',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Select a workout to log, or create a new one.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (workouts.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'You have no saved workouts yet. Add one to get started.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                ...workouts.map(_buildWorkoutTile),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isOpening ? null : _addWorkout,
                icon: const Icon(Icons.add),
                label: const Text('Add workout'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _selectedWorkout == null || _isOpening
                    ? null
                    : _logSelectedWorkout,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  _isOpening
                      ? 'Opening…'
                      : _selectedWorkout == null
                      ? 'Select a workout to log'
                      : 'Log ${_selectedWorkout!.workoutName ?? 'workout'}',
                ),
              ),
            ],
          );
  }

  Widget _buildWorkoutTile(Workout workout) {
    final selected = _selectedWorkout?.id == workout.id;
    final details = [
      workout.muscleGroup,
      workout.muscle,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' • ');

    return Card(
      child: ListTile(
        selected: selected,
        onTap: () => setState(() => _selectedWorkout = workout),
        leading: const CircleAvatar(child: Icon(Icons.fitness_center)),
        title: Text(workout.workoutName ?? 'Workout'),
        subtitle: details.isEmpty ? null : Text(details),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? Theme.of(context).colorScheme.primary : null,
            ),
            if (workout.id != null)
              IconButton(
                tooltip: 'Delete ${workout.workoutName ?? 'workout'}',
                onPressed: _deletingWorkoutIds.contains(workout.id)
                    ? null
                    : () => _deleteWorkout(workout),
                icon: _deletingWorkoutIds.contains(workout.id)
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddWorkoutDialog extends StatefulWidget {
  const _AddWorkoutDialog({required this.musclesByGroup});

  final Map<String, List<String>> musclesByGroup;

  @override
  State<_AddWorkoutDialog> createState() => _AddWorkoutDialogState();
}

class _AddWorkoutDialogState extends State<_AddWorkoutDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedGroup;
  String? _selectedMuscle;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add workout'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameController,
            autofocus: true,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Workout name'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter a workout name'
                : null,
          ),
          DropdownButtonFormField<String>(
            initialValue: _selectedGroup,
            decoration: const InputDecoration(labelText: 'Muscle group'),
            items: [
              for (final group in widget.musclesByGroup.keys)
                DropdownMenuItem(value: group, child: Text(group)),
            ],
            validator: (value) =>
                value == null ? 'Select a muscle group' : null,
            onChanged: (group) => setState(() {
              _selectedGroup = group;
              _selectedMuscle = null;
            }),
          ),
          DropdownButtonFormField<String>(
            key: ValueKey(_selectedGroup),
            initialValue: _selectedMuscle,
            decoration: const InputDecoration(labelText: 'Muscle'),
            items: [
              for (final muscle
                  in widget.musclesByGroup[_selectedGroup] ?? const <String>[])
                DropdownMenuItem(value: muscle, child: Text(muscle)),
            ],
            validator: (value) => value == null ? 'Select a muscle' : null,
            onChanged: _selectedGroup == null
                ? null
                : (muscle) => setState(() => _selectedMuscle = muscle),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, (
            name: _nameController.text.trim(),
            muscleGroup: _selectedGroup!,
            muscle: _selectedMuscle!,
          ));
        },
        child: const Text('Save'),
      ),
    ],
  );
}
