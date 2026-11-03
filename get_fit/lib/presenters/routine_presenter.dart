import '../models/routine_model.dart';

class RoutinePresenter {
  final List<Routine> _routines = [];

  List<Routine> get routines => _routines;

  Future<void> loadRoutines() async {
    final loadedRoutines = await Routine.loadRoutines();
    _routines.clear();
    _routines.addAll(loadedRoutines);
  }

  Future<void> addRoutine(Routine routine) async {
    await routine.addRoutine(routine);
    _routines.add(routine);
  }

  Future<void> deleteRoutine(String routineId) async {
    final routine = _routines.firstWhere((routine) => routine.id == routineId);
    await routine.deleteRoutine(routineId);
    _routines.removeWhere((routine) => routine.id == routineId);
  }
  
}