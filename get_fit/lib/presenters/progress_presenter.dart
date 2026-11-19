import '../models/progress_model.dart';

class ProgressChartData {
  const ProgressChartData({
    required this.values,
    required this.weeklyVolumes,
    required this.weekLabels,
    required this.volumeLabels,
    required this.hasWorkouts,
  });

  final List<double> values;
  final List<double> weeklyVolumes;
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
      weeklyVolumes: volumes,
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

  ProgressGraphAnalysis analyze() {
    if (!hasWorkouts || weeklyVolumes.isEmpty) {
      return const ProgressGraphAnalysis(hasData: false);
    }

    final count = weeklyVolumes.length;
    final meanX = (count - 1) / 2;
    final meanY = weeklyVolumes.reduce((a, b) => a + b) / count;
    var covariance = 0.0;
    var variance = 0.0;
    for (var index = 0; index < count; index++) {
      final distance = index - meanX;
      covariance += distance * (weeklyVolumes[index] - meanY);
      variance += distance * distance;
    }

    final weeklyChange = variance == 0 ? 0.0 : covariance / variance;
    final intercept = meanY - weeklyChange * meanX;
    final nextWeekVolume = intercept + weeklyChange * count;
    return ProgressGraphAnalysis(
      hasData: true,
      weeklyChange: weeklyChange,
      nextWeekVolume: nextWeekVolume < 0 ? 0 : nextWeekVolume,
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

class ProgressGraphAnalysis {
  const ProgressGraphAnalysis({
    required this.hasData,
    this.weeklyChange = 0,
    this.nextWeekVolume = 0,
  });

  final bool hasData;
  final double weeklyChange;
  final double nextWeekVolume;

  String get trend {
    if (weeklyChange > 1) return 'Increasing';
    if (weeklyChange < -1) return 'Decreasing';
    return 'Stable';
  }
}

class ProgressPresenter {
  ProgressPresenter({ProgressModel? model}) : _model = model ?? ProgressModel();

  final ProgressModel _model;

  Stream<ProgressChartData> watchChart() =>
      _model.watchWeeklyVolume().map(ProgressChartData.fromWeeklyVolumes);
}
