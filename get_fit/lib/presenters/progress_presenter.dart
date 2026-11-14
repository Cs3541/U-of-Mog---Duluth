// Add the functions for the buttons here

import 'package:flutter/material.dart';
import 'package:draw_graph/models/feature.dart';

class ProgressPresenter {
  List<Feature> get features => [
    Feature(
      title: 'Progress',
      color: Colors.blue,
      data: [0.5, 0.65, 0.775, 0.85, 1.0],
    ),
  ];
}