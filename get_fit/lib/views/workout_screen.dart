import 'package:flutter/material.dart';

import '../models/exercise_model.dart';
import '../presenters/logging_presenter.dart';
import 'routine_screen.dart';
import 'workout_logging_screen.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  final _model = LoggingModel();
  List<WorkoutHistoryEntry> _history = [];
  Map<String, dynamic>? _draft;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _model.loadWorkoutHistory(),
        LoggingPresenter.loadDraft(),
      ]);
      if (!mounted) return;
      setState(() {
        _history = results[0] as List<WorkoutHistoryEntry>;
        _draft = results[1] as Map<String, dynamic>?;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _start({
    WorkoutHistoryEntry? repeat,
    Map<String, dynamic>? draft,
    bool edit = false,
  }) async {
    if (draft == null && _draft != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unfinished workout'),
          content: const Text(
            'Resume it or discard it before opening another workout?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'discard'),
              child: const Text('Discard and continue'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'resume'),
              child: const Text('Resume'),
            ),
          ],
        ),
      );
      if (!mounted || choice == null || choice == 'cancel') return;
      if (choice == 'resume') {
        await _start(draft: _draft);
        return;
      }
      await LoggingPresenter.clearDraft();
      if (!mounted) return;
      setState(() => _draft = null);
    }
    final exercises = repeat?.exercises ?? const <ExerciseLog>[];
    final initialDraft = draft == null
        ? const <Map<String, dynamic>>[]
        : (draft['exercises'] as List? ?? const [])
              .whereType<Map>()
              .map((entry) => Map<String, dynamic>.from(entry))
              .toList();
    final completed = edit
        ? List<bool>.filled(exercises.length, true)
        : draft == null
        ? const <bool>[]
        : (draft['exercises'] as List? ?? const [])
              .map((item) => item is Map && item['completed'] == true)
              .toList();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkoutLoggingScreen(
          workoutName: edit
              ? repeat?.workoutName
              : draft == null
              ? null
              : draft['workoutName'] as String?,
          initialExercises: exercises,
          initialCompleted: completed,
          initialDraft: initialDraft,
          existingWorkoutId: edit
              ? repeat?.id
              : draft?['existingWorkoutId'] as String?,
          startedAt: edit
              ? repeat?.completedAt
              : DateTime.tryParse(draft?['startedAt'] as String? ?? ''),
        ),
      ),
    );
    if (!mounted) return;
    if (saved == true) await _load();
    if (draft != null && mounted) {
      final restored = await LoggingPresenter.loadDraft();
      if (mounted) setState(() => _draft = restored);
    }
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WorkoutHistoryScreen(
          history: _history,
          onEdit: (entry) {
            Navigator.of(context).pop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _start(repeat: entry, edit: true);
            });
          },
          onDelete: _delete,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _delete(WorkoutHistoryEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this workout?'),
        content: Text(entry.workoutName),
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
    if (confirm != true) return;
    final error = await _model.deleteWorkout(entry.id);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
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
          child: TabBarView(children: [_workoutsTab(), const RoutineScreen()]),
        ),
      ],
    ),
  );

  Widget _workoutsTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load workout history.'),
            TextButton(
              onPressed: () {
                setState(() => _loading = true);
                _load();
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    final recent = _history.take(20).toList();
    return ListView(
      padding: const EdgeInsets.only(top: 20, bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton.icon(
            onPressed: () => _start(),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start workout'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
          ),
        ),
        if (_draft != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: OutlinedButton.icon(
              onPressed: () => _start(draft: _draft),
              icon: const Icon(Icons.restore),
              label: const Text('Resume unfinished workout'),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Recent workouts',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: _openHistory,
                child: const Text('View history'),
              ),
            ],
          ),
        ),
        if (recent.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Your completed workouts will appear here.',
              textAlign: TextAlign.center,
            ),
          )
        else
          SizedBox(
            height: 186,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: recent.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) => SizedBox(
                width: 270,
                child: _historyCard(recent[index], compact: true),
              ),
            ),
          ),
        if (_history.length > 20)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Showing the latest 20. View history to see older workouts.',
            ),
          ),
      ],
    );
  }

  Widget _historyCard(WorkoutHistoryEntry entry, {bool compact = false}) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.workoutName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                _date(entry.completedAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (entry.muscleGroups.isNotEmpty)
                Text(
                  entry.muscleGroups.join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Expanded(
                child: Text(
                  entry.exercises
                      .map((set) => set.exerciseName)
                      .toSet()
                      .join(' • '),
                  maxLines: compact ? 2 : 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _start(repeat: entry),
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('Repeat'),
                ),
              ),
            ],
          ),
        ),
      );

  String _date(DateTime? date) {
    if (date == null) return 'Date unavailable';
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }
}

class WorkoutHistoryScreen extends StatelessWidget {
  const WorkoutHistoryScreen({
    required this.history,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final List<WorkoutHistoryEntry> history;
  final ValueChanged<WorkoutHistoryEntry> onEdit;
  final ValueChanged<WorkoutHistoryEntry> onDelete;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Workout history')),
    body: history.isEmpty
        ? const Center(child: Text('No completed workouts yet.'))
        : ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final entry in history)
                Card(
                  child: ExpansionTile(
                    title: Text(entry.workoutName),
                    subtitle: Text(
                      [
                        _localDate(entry.completedAt),
                        if (entry.muscleGroups.isNotEmpty)
                          entry.muscleGroups.join(' • '),
                      ].join(' • '),
                    ),
                    children: [
                      for (final set in entry.exercises)
                        ListTile(
                          dense: true,
                          title: Text(set.exerciseName),
                          subtitle: Text('${set.reps} reps • ${set.weight} lb'),
                        ),
                      OverflowBar(
                        alignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => onEdit(entry),
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit'),
                          ),
                          TextButton.icon(
                            onPressed: () => onDelete(entry),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
  );

  String _localDate(DateTime? date) {
    if (date == null) return 'Date unavailable';
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }
}
