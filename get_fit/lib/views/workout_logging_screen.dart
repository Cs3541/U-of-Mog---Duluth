import 'package:flutter/material.dart';

import '../models/exercise_model.dart';
import '../presenters/logging_presenter.dart';

class WorkoutLoggingScreen extends StatefulWidget {
  const WorkoutLoggingScreen({
    super.key,
    this.presenter,
    this.onSaveStarted,
    this.workoutName,
    this.muscleGroup,
    this.muscle,
  });

  final LoggingPresenter? presenter;
  final ValueChanged<Future<String?>>? onSaveStarted;
  final String? workoutName;
  final String? muscleGroup;
  final String? muscle;

  @override
  State<WorkoutLoggingScreen> createState() => _WorkoutLoggingScreenState();
}

class _WorkoutLoggingScreenState extends State<WorkoutLoggingScreen> {
  late final _presenter = widget.presenter ?? LoggingPresenter();
  bool _saving = false;
  bool _canLeave = false;
  bool _showingDiscard = false;
  String? _error;

  Future<void> _leave() async {
    if (_saving) {
      _close(null);
      return;
    }
    if (_showingDiscard) return;
    _showingDiscard = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard workout?'),
        content: const Text('This unfinished workout has not been saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep logging'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    _showingDiscard = false;
    if (discard == true && mounted) _close(false);
  }

  void _close(bool? saved) {
    if (_canLeave) return;
    setState(() => _canLeave = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(saved);
    });
  }

  Future<void> _addExercise() async {
    final name = await showSearch<String?>(
      context: context,
      delegate: _ExerciseSearch(
        _presenter.exercises.map((e) => e.name).toSet(),
      ),
    );
    if (!mounted || name == null || !_presenter.canAddSet) return;
    final exercise = WorkoutExercise(name);
    setState(() {
      _presenter.exercises.add(exercise);
      _error = null;
    });
    await _presenter.loadPrevious(exercise);
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final save = _presenter.save(workoutName: widget.workoutName);
      widget.onSaveStarted?.call(save);
      final error = await save;
      if (!mounted || _canLeave) return;
      if (error == null) {
        _close(true);
        return;
      }
      setState(() {
        _error = error;
        _saving = false;
      });
    } catch (_) {
      if (mounted && !_canLeave) {
        setState(() {
          _error =
              'Could not save. Your entries are still here; please try again.';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<bool>(
    canPop: _canLeave,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.workoutName == null
              ? 'Log workout'
              : 'Log ${widget.workoutName}',
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.muscleGroup != null || widget.muscle != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.fitness_center),
                  title: Text(widget.workoutName ?? 'Selected workout'),
                  subtitle: Text(
                    [
                      widget.muscleGroup,
                      widget.muscle,
                    ].whereType<String>().join(' • '),
                  ),
                ),
              ),
            if (_saving)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Saving workout. You can go back while it finishes.',
                ),
              ),
            if (_presenter.exercises.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('Add an exercise to start logging your sets.'),
              ),
            for (final exercise in _presenter.exercises)
              _exerciseCard(exercise),
            OutlinedButton.icon(
              onPressed: _presenter.canAddSet ? _addExercise : null,
              icon: const Icon(Icons.add),
              label: const Text('Add exercise'),
            ),
            Text(
              '${_presenter.setCount}/${LoggingModel.maxWorkoutSets} sets • Weight in lb; use 0 for bodyweight.',
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(_saving ? 'Saving…' : 'Finish workout'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _exerciseCard(WorkoutExercise exercise) => Card(
    key: ObjectKey(exercise),
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  exercise.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Remove ${exercise.name}',
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    setState(() => _presenter.exercises.remove(exercise)),
              ),
            ],
          ),
          Text(
            exercise.loadingPrevious
                ? 'Loading previous sets…'
                : exercise.historyError ??
                      (exercise.previous.isEmpty
                          ? 'No previous sets.'
                          : 'Gray hints show your last workout.'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (var i = 0; i < exercise.sets.length; i++) _setRow(exercise, i),
          TextButton.icon(
            onPressed: _presenter.canAddSet
                ? () => setState(() => exercise.sets.add(WorkoutSet()))
                : null,
            icon: const Icon(Icons.add),
            label: const Text('Add set'),
          ),
        ],
      ),
    ),
  );

  Widget _setRow(WorkoutExercise exercise, int index) {
    final set = exercise.sets[index];
    final previous = index < exercise.previous.length
        ? exercise.previous[index]
        : null;
    return Padding(
      key: ObjectKey(set),
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text('${index + 1}')),
          Expanded(
            child: TextFormField(
              initialValue: set.weight,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Weight (lb)',
                hintText: previous?.weight.toString(),
                hintStyle: const TextStyle(color: Colors.grey),
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              onChanged: (value) => setState(() {
                set.weight = value;
                set.completed = false;
              }),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              initialValue: set.reps,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Reps',
                hintText: previous?.reps.toString(),
                hintStyle: const TextStyle(color: Colors.grey),
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              onChanged: (value) => setState(() {
                set.reps = value;
                set.completed = false;
              }),
            ),
          ),
          Checkbox(
            value: set.completed,
            activeColor: Colors.green,
            semanticLabel: '${exercise.name} set ${index + 1} complete',
            onChanged: (checked) => setState(() {
              if (checked == true && set.error != null) {
                _error = set.error;
                return;
              }
              _error = null;
              set.completed = checked ?? false;
            }),
          ),
          IconButton(
            tooltip: 'Remove ${exercise.name} set ${index + 1}',
            icon: const Icon(Icons.close),
            onPressed: () => setState(() {
              exercise.sets.remove(set);
              if (exercise.sets.isEmpty) _presenter.exercises.remove(exercise);
            }),
          ),
        ],
      ),
    );
  }
}

class _ExerciseSearch extends SearchDelegate<String?> {
  _ExerciseSearch(this.selected) : super(searchFieldLabel: 'Search exercises');
  final Set<String> selected;

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(
      tooltip: 'Clear search',
      icon: const Icon(Icons.clear),
      onPressed: () => query = '',
    ),
  ];
  @override
  Widget buildLeading(BuildContext context) =>
      BackButton(onPressed: () => close(context, null));
  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
  @override
  Widget buildResults(BuildContext context) {
    final matches = LoggingModel.commonExercises
        .where(
          (name) =>
              !selected.contains(name) &&
              name.toLowerCase().contains(query.trim().toLowerCase()),
        )
        .toList();
    if (matches.isEmpty) {
      return const Center(child: Text('No matching exercises to add.'));
    }
    return ListView(
      children: [
        for (final name in matches)
          ListTile(title: Text(name), onTap: () => close(context, name)),
      ],
    );
  }
}
