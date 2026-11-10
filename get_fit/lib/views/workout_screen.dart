import 'package:flutter/material.dart';
import '../presenters/workout_presenter.dart';


class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final WorkoutPresenter _presenter = WorkoutPresenter();
  bool _isLoading = true;
  String? _loadError;

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
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final muscleGroupController = TextEditingController();
    final muscleController = TextEditingController();

    final details =
        await showDialog<({String name, String? muscleGroup, String? muscle})>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Add workout'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Workout name',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a workout name'
                        : null,
                  ),
                  TextFormField(
                    controller: muscleGroupController,
                    decoration: const InputDecoration(
                      labelText: 'Muscle group',
                    ),
                  ),
                  TextFormField(
                    controller: muscleController,
                    decoration: const InputDecoration(labelText: 'Muscle'),
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
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context, (
                      name: nameController.text.trim(),
                      muscleGroup: _optionalText(muscleGroupController.text),
                      muscle: _optionalText(muscleController.text),
                    ));
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );

    nameController.dispose();
    muscleGroupController.dispose();
    muscleController.dispose();
    if (details == null || !mounted) return;

    try {
      await _presenter.addWorkout(
        workoutName: details.name,
        muscleGroup: details.muscleGroup,
        muscle: details.muscle,
      );
      if (mounted) {
        setState(() {
          _loadError = null;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add workout: $error')));
    }
  }

  String? _optionalText(String value) {
    final trimmedValue = value.trim();
    return trimmedValue.isEmpty ? null : trimmedValue;
  }

  @override
  Widget build(BuildContext context) {
    final workouts = _presenter.workouts;

    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Could not load workouts: $_loadError'),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      setState(() => _isLoading = true);
                      _loadWorkouts();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : workouts.isEmpty
          ? const Center(child: Text('No workouts yet. Add your first one.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: workouts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final workout = workouts[index];
                final details = [
                  workout.muscleGroup,
                  workout.muscle,
                ].whereType<String>().where((value) => value.isNotEmpty);

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.fitness_center),
                    ),
                    title: Text(workout.workoutName ?? 'Workout'),
                    subtitle: details.isEmpty
                        ? null
                        : Text(details.join(' • ')),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addWorkout,
        icon: const Icon(Icons.add),
        label: const Text('Add workout'),
      ),
    );
  }
}
