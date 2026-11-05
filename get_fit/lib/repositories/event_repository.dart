
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';

class EventRepository {

  // Connect to the events collection in Firebase
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('events');

  // Retrieve events in real time, ordered by date
  Stream<List<Event>> watchEvents() {
    return _col
        .orderBy('date')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(Event.fromDoc).toList();
    });
  }

  // Add a new event
  Future<void> add(Event event) {
    return _col.add(event.toMap());
  }

  // Restore an event using its original ID (Undo)
  Future<void> restore(Event event) {
    return _col.doc(event.id).set(event.toMap());
  }

  // Delete an event
  Future<void> delete(String id) {
    return _col.doc(id).delete();
  }
}
