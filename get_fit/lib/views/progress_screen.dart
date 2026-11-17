import 'package:draw_graph/draw_graph.dart';
import 'package:draw_graph/models/feature.dart';
import 'package:flutter/material.dart';

import '../presenters/progress_presenter.dart';

enum _ProgressGraphType { line, area }

enum _ProgressCustomization { type, color, axes, legendName }

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
  String _xAxisName = 'Weeks';
  String _yAxisName = 'Volume (lbs)';
  String _legendName = 'Progress';

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
            ListTile(
              title: const Text('Change axis names'),
              onTap: () => Navigator.pop(context, _ProgressCustomization.axes),
            ),
            ListTile(
              title: const Text('Change legend name'),
              onTap: () =>
                  Navigator.pop(context, _ProgressCustomization.legendName),
            ),
          ],
        ),
      ),
    );

    if (!mounted || customization == null) return;
    if (customization == _ProgressCustomization.type) {
      await _selectGraphType();
    } else if (customization == _ProgressCustomization.color) {
      await _selectGraphColor();
    } else if (customization == _ProgressCustomization.axes) {
      await _selectAxisNames();
    } else {
      await _selectLegendName();
    }
  }

  Future<void> _selectLegendName() async {
    final controller = TextEditingController(text: _legendName);
    final formKey = GlobalKey<FormState>();
    final selectedName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change legend name'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Legend name'),
            maxLength: 30,
            validator: _validateLabel,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (!mounted || selectedName == null) return;
    setState(() => _legendName = selectedName);
  }

  Future<void> _selectAxisNames() async {
    final xAxisController = TextEditingController(text: _xAxisName);
    final yAxisController = TextEditingController(text: _yAxisName);
    final formKey = GlobalKey<FormState>();
    final selectedNames = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change axis names'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: xAxisController,
                decoration: const InputDecoration(labelText: 'Horizontal axis'),
                maxLength: 30,
                validator: _validateLabel,
              ),
              TextFormField(
                controller: yAxisController,
                decoration: const InputDecoration(labelText: 'Vertical axis'),
                maxLength: 30,
                validator: _validateLabel,
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
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(context, (
                xAxisController.text.trim(),
                yAxisController.text.trim(),
              ));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    xAxisController.dispose();
    yAxisController.dispose();

    if (!mounted || selectedNames == null) return;
    setState(() {
      _xAxisName = selectedNames.$1;
      _yAxisName = selectedNames.$2;
    });
  }

  String? _validateLabel(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter an axis name.';
    }
    return null;
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: StreamBuilder<ProgressChartData>(
        stream: _chart,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final chart = snapshot.data!;
          final feature = Feature(
            title: _legendName,
            color: _chartColor,
            data: chart.volumeLabels
                .map((label) => double.tryParse(label) ?? 0)
                .toList(),
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
                      SizedBox(
                        width: 42,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 140),
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Text(
                              _yAxisName,
                          
                              style: const TextStyle(
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
                const SizedBox(height: 8),
                Text(
                  _xAxisName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
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
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text('Share'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
