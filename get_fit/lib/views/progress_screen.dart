import 'package:draw_graph/draw_graph.dart';
import 'package:draw_graph/models/feature.dart';
import 'package:flutter/material.dart';

import '../presenters/progress_presenter.dart';

enum _ProgressGraphType { line, area }

enum _ProgressCustomization { type, color }

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => ProgressScreenState();
}

class ProgressScreenState extends State<ProgressScreen> {
  final ProgressPresenter _presenter = ProgressPresenter();
  late final Stream<ProgressChartData> _chart = _presenter.watchChart();
  _ProgressGraphType _graphType = _ProgressGraphType.area;
  Color _chartColor = Colors.blue;

  Future<void> _customizeGraph() async {
    final customization = await showDialog<_ProgressCustomization>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Customize graph'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Change type'),
              onTap: () => Navigator.pop(context, _ProgressCustomization.type),
            ),
            ListTile(
              title: const Text('Change color'),
              onTap: () => Navigator.pop(context, _ProgressCustomization.color),
            ),
          ],
        ),
      ),
    );

    if (!mounted || customization == null) return;
    if (customization == _ProgressCustomization.type) {
      await _selectGraphType();
    } else {
      await _selectGraphColor();
    }
  }

  Future<void> _selectGraphType() async {
    final selectedType = await showDialog<_ProgressGraphType>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose graph type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Line'),
              trailing: _graphType == _ProgressGraphType.line
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(context, _ProgressGraphType.line),
            ),
            ListTile(
              title: const Text('Area'),
              trailing: _graphType == _ProgressGraphType.area
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(context, _ProgressGraphType.area),
            ),
          ],
        ),
      ),
    );

    if (!mounted || selectedType == null) return;
    setState(() => _graphType = selectedType);
  }

  Future<void> _selectGraphColor() async {
    const colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
    ];
    const colorNames = ['Blue', 'Red', 'Green', 'Orange', 'Purple'];
    final selectedColor = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose graph color'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < colors.length; index++)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: colors[index],
                  radius: 10,
                ),
                title: Text(colorNames[index]),
                trailing: _chartColor == colors[index]
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, colors[index]),
              ),
          ],
        ),
      ),
    );

    if (!mounted || selectedColor == null) return;
    setState(() => _chartColor = selectedColor);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Progress')),
    body: StreamBuilder<ProgressChartData>(
      stream: _chart,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Unable to load workout progress: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final chart = snapshot.data!;
        final feature = Feature(
          title: 'Weekly volume',
          color: _chartColor,
          data: chart.values,
        );
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 42,
                      child: Padding(
                        padding: EdgeInsets.only(top: 140),
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            'Volume (lb-reps)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: LineGraph(
                        features: [feature],
                        size: Size(MediaQuery.sizeOf(context).width - 80, 300),
                        labelX: chart.weekLabels,
                        labelY: chart.volumeLabels,
                        graphOpacity: _graphType == _ProgressGraphType.area
                            ? 0.3
                            : 0,
                        showDescription: false,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Weeks',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              if (!chart.hasWorkouts)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('No workout data for the last 5 weeks.'),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: feature.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(feature.title, style: const TextStyle(fontSize: 13)),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _customizeGraph,
                    child: const Text('Customize'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Analysis'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(onPressed: () {}, child: const Text('Share')),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}
