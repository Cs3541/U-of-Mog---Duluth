
import 'package:flutter/material.dart';

import '../models/event_model.dart';
import '../repositories/event_repository.dart';

class EventsPresenter extends ChangeNotifier {

  // Repository connection
  final EventRepository _repository;

  EventsPresenter({EventRepository? repository})
      : _repository = repository ?? EventRepository();

  // Stream of events from Firebase
  late final Stream<List<Event>> _eventsStream =
    _repository.watchEvents();

Stream<List<Event>> get eventsStream => _eventsStream;

  // Search and filter information
  String searchQuery = '';
  EventCategory? selectedCategory;

  // Calendar information
  DateTime selectedDay = DateTime.now();
  DateTime focusedDay = DateTime.now();

  // Update search
  void searchEvents(String query) {
    searchQuery = query;
    notifyListeners();
  }

  // Update category filter
  void filterEvents(EventCategory? category) {
    selectedCategory = category;
    notifyListeners();
  }

  // Select a calendar day
  void selectDay(DateTime selected, DateTime focused) {
    selectedDay = selected;
    focusedDay = focused;
    notifyListeners();
  }

  // Update the focused calendar day
  void updateFocusedDay(DateTime focused) {
    focusedDay = focused;
    notifyListeners();
  }

  // Add an event
  Future<void> addEvent(Event event) async {
    await _repository.add(event);

    selectedDay = event.date;
    focusedDay = event.date;

    notifyListeners();
  }

  // Delete an event
  Future<void> deleteEvent(Event event) async {
    await _repository.delete(event.id);
  }

  // Restore a deleted event
  Future<void> restoreEvent(Event event) async {
    await _repository.restore(event);
  }
}
