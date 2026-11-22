import 'dart:async';

import 'package:flutter/material.dart';

import '../models/exercise_model.dart';
import '../presenters/exp_presenter.dart';
import '../presenters/logging_presenter.dart';

class WorkoutLoggingScreen extends StatefulWidget {
  const WorkoutLoggingScreen({
    super.key,
    this.presenter,
    this.onSaveStarted,
    this.workoutName,
    this.muscleGroup,
    this.muscle,
    this.initialExercises = const [],
    this.initialCompleted = const [],
    this.initialDraft = const [],
    this.existingWorkoutId,
    this.startedAt,
  });

  final LoggingPresenter? presenter;
  final ValueChanged<Future<String?>>? onSaveStarted;
  final String? workoutName;
  final String? muscleGroup;
  final String? muscle;
  final List<ExerciseLog> initialExercises;
  final List<bool> initialCompleted;
  final List<Map<String, dynamic>> initialDraft;
  final String? existingWorkoutId;
  final DateTime? startedAt;

  @override
  State<WorkoutLoggingScreen> createState() => _WorkoutLoggingScreenState();
}

class _WorkoutLoggingScreenState extends State<WorkoutLoggingScreen> {
  late final _presenter =
      widget.presenter ??
      LoggingPresenter(
        initialExercises: widget.initialExercises,
        initialCompleted: widget.initialCompleted,
        initialDraft: widget.initialDraft,
        existingWorkoutId: widget.existingWorkoutId,
        startedAt: widget.startedAt,
        workoutName: widget.workoutName,
      );
  final _expPresenter = ExpPresenter();
  late final _workoutNameController = TextEditingController(
    text: widget.workoutName ?? '',
  );
  final _routineNameController = TextEditingController();
  bool _saving = false;
  bool _loadingExercises = false;
  bool _canLeave = false;
  bool _showingDiscard = false;
  bool _saveAsRoutine = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_presenter.exercises.isNotEmpty) unawaited(_loadInitialExercises());
  }

  Future<void> _loadInitialExercises() async {
    try {
      await _presenter.loadCommonExercises();
    } catch (_) {
      // History and entered values remain usable if the catalog is offline.
    }
    await Future.wait(_presenter.exercises.map(_presenter.loadPrevious));
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _workoutNameController.dispose();
    _routineNameController.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_saving) return;
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
    if (discard == true && mounted) {
      await LoggingPresenter.clearDraft();
      _close(false);
    }
  }

  void _persistDraft() {
    unawaited(_presenter.saveDraft(workoutName: _workoutNameController.text));
  }

  void _close(bool? saved) {
    if (_canLeave) return;
    setState(() => _canLeave = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(saved);
    });
  }

  Future<void> _addExercise() async {
    if (_loadingExercises || _saving) return;
    setState(() {
      _loadingExercises = true;
      _error = null;
    });
    late final List<String> names;
    try {
      names = await _presenter.loadCommonExercises();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not load exercises. Tap Add exercise to retry.',
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _loadingExercises = false);
    }
    if (!mounted || _canLeave || _showingDiscard) return;
    if (names.isEmpty) {
      setState(() => _error = 'No common exercises have been added yet.');
      return;
    }
    final name = await showSearch<String?>(
      context: context,
      delegate: _ExerciseSearch(
        _presenter.exercises.map((e) => e.name.toLowerCase()).toSet(),
        names,
      ),
    );
    if (!mounted || name == null || !_presenter.canAddSet) return;
    final exercise = WorkoutExercise(name);
    setState(() {
      _presenter.exercises.add(exercise);
      _error = null;
    });
    _persistDraft();
    await _presenter.loadPrevious(exercise);
    if (mounted) setState(() {});
  }

  Future<void> _awardExp() async {
    try {
      await _expPresenter.awardWorkout();
    } catch (e) {
      debugPrint('EXP award failed: $e');
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final unchecked = [
      for (final exercise in _presenter.exercises)
        for (final set in exercise.sets)
          if (!set.completed) (exercise, set),
    ];
    if (unchecked.isNotEmpty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unfinished sets'),
          content: const Text(
            'Mark every set complete, or leave the unchecked sets out of this workout?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Keep logging'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'remove'),
              child: const Text('Remove unchecked'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'complete'),
              child: const Text('Mark all complete'),
            ),
          ],
        ),
      );
      if (!mounted || choice == null || choice == 'cancel') return;
      if (choice == 'complete') {
        for (final (_, set) in unchecked) {
          set.completed = true;
        }
      } else {
        for (final (exercise, set) in unchecked) {
          exercise.sets.remove(set);
          if (exercise.sets.isEmpty) _presenter.exercises.remove(exercise);
        }
      }
      _persistDraft();
    }
    if (_presenter.setCount == 0) {
      setState(() => _error = 'Keep at least one finished set to save.');
      return;
    }
    if (_saveAsRoutine && _routineNameController.text.trim().isEmpty) {
      setState(() => _error = 'Enter a name for this private routine.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final save = _presenter
          .save(
            workoutName: _workoutNameController.text.trim().isEmpty
                ? null
                : _workoutNameController.text.trim(),
            routineName: _saveAsRoutine
                ? _routineNameController.text.trim()
                : null,
          )
          .then((error) {
            if (error == null && _presenter.existingWorkoutId == null) {
              unawaited(_awardExp());
            }
            return error;
          });
      widget.onSaveStarted?.call(save);
      final error = await save;
      if (!mounted || _canLeave) return;
      if (error == null) {
        await LoggingPresenter.clearDraft();
        _close(true);
        return;
      }
      setState(() {
        _error = error;
        _saving = false;
      });
      _persistDraft();
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
          widget.existingWorkoutId == null ? 'Log workout' : 'Edit workout',
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _workoutNameController,
              maxLength: 100,
              onChanged: (_) => _persistDraft(),
              decoration: const InputDecoration(
                labelText: 'Workout name (optional)',
                hintText: 'Date and exercises will name it automatically',
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _saveAsRoutine,
              title: const Text('Save as a private routine'),
              subtitle: const Text('Only you can access this routine.'),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _saveAsRoutine = value ?? false;
                      _error = null;
                      _persistDraft();
                    }),
            ),
            if (_saveAsRoutine)
              TextField(
                controller: _routineNameController,
                maxLength: 100,
                onChanged: (_) => _persistDraft(),
                decoration: const InputDecoration(
                  labelText: 'Routine name',
                  hintText: 'e.g. Heavy Push Routine',
                ),
              ),
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
                  'Saving workout. Please stay on this screen until it finishes.',
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
              onPressed: _presenter.canAddSet && !_loadingExercises
                  ? _addExercise
                  : null,
              icon: const Icon(Icons.add),
              label: Text(
                _loadingExercises ? 'Loading exercises…' : 'Add exercise',
              ),
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
            if (_presenter.exercises.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Muscle groups',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _presenter.muscleGroups.isEmpty
                            ? 'No group tags for these exercises yet.'
                            : _presenter.muscleGroups.join(' • '),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Exercises',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(_presenter.exercises.map((e) => e.name).join(' • ')),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving || _loadingExercises ? null : _save,
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
                onPressed: () => setState(() {
                  _presenter.exercises.remove(exercise);
                  _persistDraft();
                }),
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
                ? () => setState(() {
                    exercise.sets.add(WorkoutSet());
                    _persistDraft();
                  })
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
                _persistDraft();
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
                _persistDraft();
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
              _persistDraft();
            }),
          ),
          IconButton(
            tooltip: 'Remove ${exercise.name} set ${index + 1}',
            icon: const Icon(Icons.close),
            onPressed: () => setState(() {
              exercise.sets.remove(set);
              if (exercise.sets.isEmpty) _presenter.exercises.remove(exercise);
              _persistDraft();
            }),
          ),
        ],
      ),
    );
  }
}

class _ExerciseSearch extends SearchDelegate<String?> {
  _ExerciseSearch(this.selected, this.names)
    : super(searchFieldLabel: 'Search exercises');
  final Set<String> selected;
  final List<String> names;

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
    final matches = names
        .where(
          (name) =>
              !selected.contains(name.toLowerCase()) &&
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
