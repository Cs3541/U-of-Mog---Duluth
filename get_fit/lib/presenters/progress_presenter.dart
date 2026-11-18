import '../models/progress_model.dart';

class ProgressChartData {
  const ProgressChartData({
    required this.values,
    required this.weekLabels,
    required this.volumeLabels,
    required this.hasWorkouts,
  });

  final List<double> values;
  final List<String> weekLabels;
  final List<String> volumeLabels;
  final bool hasWorkouts;

  factory ProgressChartData.fromWeeklyVolumes(
    List<WeeklyVolume> weeks, {
    DateTime? today,
  }) {
    final volumes = weeks.map((week) => week.volume).toList();
    var maxVolume = 0.0;
    for (final volume in volumes) {
      if (volume > maxVolume) maxVolume = volume;
    }

    final thisWeek = _weekStart(today ?? DateTime.now());
    final firstWeek = thisWeek.subtract(Duration(days: 7 * (weeks.length - 1)));
    return ProgressChartData(
      values: [
        for (final volume in volumes) maxVolume == 0 ? 0 : volume / maxVolume,
      ],
      weekLabels: [
        for (var index = 0; index < weeks.length; index++)
          _formatDate(firstWeek.add(Duration(days: 7 * index))),
      ],
      volumeLabels: [
        for (var index = 0; index <= 4; index++)
          _formatVolume(maxVolume * (index + 1) / 5),
      ],
      hasWorkouts: weeks.any((week) => week.workoutCount > 0),
    );
  }

  static DateTime _weekStart(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static String _formatDate(DateTime date) => '${date.month}/${date.day}';

  static String _formatVolume(double volume) => volume == volume.roundToDouble()
      ? volume.toInt().toString()
      : volume.toStringAsFixed(1);
}

class ProgressPresenter {
  ProgressPresenter({ProgressModel? model}) : _model = model ?? ProgressModel();

  final ProgressModel _model;

  Stream<ProgressChartData> watchChart() =>
      _model.watchWeeklyVolume().map(ProgressChartData.fromWeeklyVolumes);
}
