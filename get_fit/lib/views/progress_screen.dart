import 'package:flutter/material.dart';
import 'package:draw_graph/draw_graph.dart';
import 'package:draw_graph/models/feature.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => ProgressScreenState();
}

class ProgressScreenState extends State<ProgressScreen> {
  final List<Feature> features = [
    Feature(
      title: 'Progress',
      color: Colors.blue,
      data: [0.5, 0.65, 0.775, 0.85, 1.0],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress')
      ),
      body: Center(
        child: LineGraph(
          features: features,
          size: Size(MediaQuery.sizeOf(context).width, 350),
          labelX: const ['W1', 'W2', 'W3', 'W4', 'W5'],
          labelY: const ['0', '25', '50', '75', '100'],
          showDescription: true,
        ),
      ),
    );
  }
}