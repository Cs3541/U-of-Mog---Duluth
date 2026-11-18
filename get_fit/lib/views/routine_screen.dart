import 'package:flutter/material.dart';

import '../models/routine_model.dart';
import '../models/workout_model.dart';
import '../presenters/routine_presenter.dart';
import 'workout_logging_screen.dart';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  final RoutinePresenter _presenter = RoutinePresenter();
  bool _isLoading = true;
  bool _isOpeningWorkout = false;
  String? _loadError;
  final Set<String> _pendingRoutineIds = {};

  @override
  void initState() {
    super.initState();
    _loadRoutines();
  }

  Future<void> _loadRoutines() async {
    try {
      await _presenter.loadRoutines();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _addRoutine() async {
    final details = await showDialog<({String name, String description})>(
      context: context,
      builder: (_) => const _AddRoutineDialog(),
    );
    if (details == null || !mounted) return;

    try {
      await _presenter.addRoutine(
        routineName: details.name,
        description: details.description,
      );
      if (!mounted) return;
      setState(() => _loadError = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Routine created.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create routine: $error')),
      );
    }
  }

  Future<void> _addWorkout(Routine routine) async {
    if (_presenter.availableWorkouts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a workout from the Workouts tab first.'),
        ),
      );
      return;
    }

    final assignment =
        await showDialog<({String workoutId, List<String> days})>(
          context: context,
          builder: (_) => _AddRoutineWorkoutDialog(
            workouts: _presenter.availableWorkouts,
            daysOfWeek: _presenter.daysOfWeek,
            existingWorkouts: routine.workouts,
          ),
        );
    final routineId = routine.id;
    if (assignment == null || routineId == null || !mounted) return;

    setState(() => _pendingRoutineIds.add(routineId));
    try {
      await _presenter.addWorkoutToRoutine(
        routineId: routineId,
        workoutId: assignment.workoutId,
        days: assignment.days,
      );
      if (!mounted) return;
      setState(() {
        _pendingRoutineIds.remove(routineId);
        _loadError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout added to routine.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _pendingRoutineIds.remove(routineId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add workout to routine: $error')),
      );
    }
  }

  Future<void> _logWorkout(RoutineWorkout assignment) async {
    if (_isOpeningWorkout) return;

    final matchingWorkouts = _presenter.availableWorkouts.where(
      (workout) => workout.id == assignment.workoutId,
    );
    final workout = matchingWorkouts.isEmpty ? null : matchingWorkouts.first;

    setState(() => _isOpeningWorkout = true);
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkoutLoggingScreen(
          workoutName: assignment.workoutName,
          muscleGroup: workout?.muscleGroup,
          muscle: workout?.muscle,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _isOpeningWorkout = false);
    if (result == true) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Workout logged.')));
    }
  }

  Future<void> _deleteRoutine(Routine routine) async {
    final routineId = routine.id;
    if (routineId == null || _pendingRoutineIds.contains(routineId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete routine?'),
        content: Text(
          'Delete "${routine.routineName ?? 'Routine'}" and its workout schedule?',
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

    setState(() => _pendingRoutineIds.add(routineId));
    try {
      await _presenter.deleteRoutine(routineId);
      if (!mounted) return;
      setState(() => _pendingRoutineIds.remove(routineId));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Routine deleted.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _pendingRoutineIds.remove(routineId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete routine: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load routines: $_loadError'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _loadError = null;
                  });
                  _loadRoutines();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Your routines', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Add workouts to a routine and choose the days you plan to do them.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _addRoutine,
          icon: const Icon(Icons.add),
          label: const Text('Create routine'),
        ),
        if (_presenter.routines.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No routines yet. Create one to start planning your workouts.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ..._presenter.routines.map(_buildRoutineCard),
      ],
    );
  }

  Widget _buildRoutineCard(Routine routine) {
    final routineId = routine.id;
    final isPending =
        routineId != null && _pendingRoutineIds.contains(routineId);

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    routine.routineName ?? 'Routine',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Delete routine',
                  onPressed: isPending ? null : () => _deleteRoutine(routine),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (routine.description?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(routine.description!),
              ),
            if (routine.workouts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No workouts in this routine yet.'),
              )
            else
              ...routine.workouts.map(
                (assignment) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.fitness_center),
                  ),
                  title: Text(assignment.workoutName),
                  subtitle: Text(assignment.days.join(' • ')),
                  trailing: IconButton(
                    tooltip: 'Log ${assignment.workoutName}',
                    onPressed: _isOpeningWorkout
                        ? null
                        : () => _logWorkout(assignment),
                    icon: const Icon(Icons.play_arrow),
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: isPending ? null : () => _addWorkout(routine),
              icon: isPending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(isPending ? 'Saving…' : 'Add workout'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddRoutineDialog extends StatefulWidget {
  const _AddRoutineDialog();

  @override
  State<_AddRoutineDialog> createState() => _AddRoutineDialogState();
}

class _AddRoutineDialogState extends State<_AddRoutineDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create routine'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameController,
            autofocus: true,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Routine name'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter a routine name'
                : null,
          ),
          TextField(
            controller: _descriptionController,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
            ),
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
            description: _descriptionController.text.trim(),
          ));
        },
        child: const Text('Create'),
      ),
    ],
  );
}

class _AddRoutineWorkoutDialog extends StatefulWidget {
  const _AddRoutineWorkoutDialog({
    required this.workouts,
    required this.daysOfWeek,
    required this.existingWorkouts,
  });

  final List<Workout> workouts;
  final List<String> daysOfWeek;
  final List<RoutineWorkout> existingWorkouts;

  @override
  State<_AddRoutineWorkoutDialog> createState() =>
      _AddRoutineWorkoutDialogState();
}

class _AddRoutineWorkoutDialogState extends State<_AddRoutineWorkoutDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedWorkoutId;
  final Set<String> _selectedDays = {};

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add workout to routine'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedWorkoutId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Workout'),
              items: [
                for (final workout in widget.workouts)
                  if (workout.id != null)
                    DropdownMenuItem(
                      value: workout.id,
                      child: Text(workout.workoutName ?? 'Workout'),
                    ),
              ],
              validator: (value) => value == null ? 'Select a workout' : null,
              onChanged: (value) => setState(() => _selectedWorkoutId = value),
            ),
            const SizedBox(height: 16),
            Text(
              'Days of the week',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                for (final day in widget.daysOfWeek)
                  FilterChip(
                    label: Text(day.substring(0, 3)),
                    selected: _selectedDays.contains(day),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _selectedDays.add(day);
                      } else {
                        _selectedDays.remove(day);
                      }
                    }),
                  ),
              ],
            ),
            if (_selectedDays.isEmpty)
              Text(
                'Choose at least one day.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_selectedWorkoutId != null &&
                widget.existingWorkouts.any(
                  (entry) => entry.workoutId == _selectedWorkoutId,
                ))
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'This workout is already in the routine. Saving will update its days.',
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate() || _selectedDays.isEmpty) {
            return;
          }
          Navigator.pop(context, (
            workoutId: _selectedWorkoutId!,
            days: _selectedDays.toList(),
          ));
        },
        child: const Text('Add workout'),
      ),
    ],
  );
}
