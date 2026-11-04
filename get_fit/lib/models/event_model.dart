
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Event categories
enum EventCategory {
  run,
  gym,
  yoga,
  cycling,
  swim,
  sports,
  other
}

// Category labels and icons
extension EventCategoryX on EventCategory {
  String get label => switch (this) {
        EventCategory.run => 'Run',
        EventCategory.gym => 'Gym',
        EventCategory.yoga => 'Yoga',
        EventCategory.cycling => 'Cycling',
        EventCategory.swim => 'Swim',
        EventCategory.sports => 'Sports',
        EventCategory.other => 'Other',
      };

  IconData get icon => switch (this) {
        EventCategory.run => Icons.directions_run,
        EventCategory.gym => Icons.fitness_center,
        EventCategory.yoga => Icons.self_improvement,
        EventCategory.cycling => Icons.directions_bike,
        EventCategory.swim => Icons.pool,
        EventCategory.sports => Icons.sports_soccer,
        EventCategory.other => Icons.event,
      };
}

// Event model
class Event {
  Event({
    required this.id,
    required this.title,
    required this.date,
    required this.category,
    this.location = '',
    this.description = '',
  });

  final String id;
  final String title;
  final DateTime date;
  final EventCategory category;
  final String location;
  final String description;

  // Convert event into Firebase data
  Map<String, dynamic> toMap() => {
        'title': title,
        'date': Timestamp.fromDate(date),
        'category': category.name,
        'location': location,
        'description': description,
      };

  // Convert Firebase document into an Event
  factory Event.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    final ts = d['date'];

    return Event(
      id: doc.id,
      title: (d['title'] as String?) ?? '',
      date: ts is Timestamp ? ts.toDate() : DateTime.now(),
      category: EventCategory.values.firstWhere(
        (c) => c.name == d['category'],
        orElse: () => EventCategory.other,
      ),
      location: (d['location'] as String?) ?? '',
      description: (d['description'] as String?) ?? '',
    );
  }
}
