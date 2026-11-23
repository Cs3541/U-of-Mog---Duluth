import 'package:flutter_test/flutter_test.dart';
import 'package:get_fit/models/progress_model.dart';
import 'package:get_fit/presenters/progress_presenter.dart';

void main() {
  group('ProgressChartData.analyze', () {
    test('identifies an increasing trend and predicts next week', () {
      final chart = ProgressChartData.fromWeeklyVolumes([
        for (final volume in [100, 200, 300, 400, 500])
          WeeklyVolume(volume: volume.toDouble(), workoutCount: 1),
      ]);

      final analysis = chart.analyze();

      expect(analysis.hasData, isTrue);
      expect(analysis.trend, 'Increasing');
      expect(analysis.weeklyChange, 100);
      expect(analysis.nextWeekVolume, 600);
    });

    test('does not analyze a graph without logged workouts', () {
      final chart = ProgressChartData.fromWeeklyVolumes([
        for (var index = 0; index < 5; index++)
          const WeeklyVolume(volume: 0, workoutCount: 0),
      ]);

      expect(chart.analyze().hasData, isFalse);
    });

    test('does not predict a negative volume for a declining trend', () {
      final chart = ProgressChartData.fromWeeklyVolumes([
        for (final volume in [400, 300, 200, 100, 0])
          WeeklyVolume(volume: volume.toDouble(), workoutCount: 1),
      ]);

      expect(chart.analyze().nextWeekVolume, 0);
    });

  });
}
