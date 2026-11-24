import 'package:cloud_firestore/cloud_firestore.dart';

class Broadcast {
  final String id;
  final String title;
  final String message;
  final DateTime? sentAt;

  const Broadcast({
    required this.id,
    required this.title,
    required this.message,
    this.sentAt,
  });

  factory Broadcast.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final ts = d['sentAt'];
    return Broadcast(
      id: doc.id,
      title: (d['title'] as String?) ?? '',
      message: (d['message'] as String?) ?? '',
      sentAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

class BroadcastRules {
  static const int maxTitleLength = 60;
  static const int maxMessageLength = 300;

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get broadcasts =>
      _db.collection('broadcasts');

  static DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      _db.collection('users').doc(uid);

  static Stream<bool> watchIsAdmin(String uid) => _db
      .collection('admins')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists)
      .handleError((_) => false);

  static Stream<List<Broadcast>> watchRecent({int limit = 5}) {
    return broadcasts
        .orderBy('sentAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Broadcast.fromDoc).toList());
  }

  static Stream<List<Broadcast>> watchAll() {
    return broadcasts
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Broadcast.fromDoc).toList());
  }

  static String? _validate(String t, String m) {
    if (t.isEmpty) return 'Please enter a title.';
    if (m.isEmpty) return 'Please enter a message.';
    if (t.length > maxTitleLength) {
      return 'Title must be $maxTitleLength characters or less.';
    }
    if (m.length > maxMessageLength) {
      return 'Message must be $maxMessageLength characters or less.';
    }
    return null;
  }

  static Future<String?> edit({
    required String id,
    required String title,
    required String message,
  }) async {
    final t = title.trim();
    final m = message.trim();
    final invalid = _validate(t, m);
    if (invalid != null) return invalid;
    try {
      await broadcasts.doc(id).update({'title': t, 'message': m});
      return null;
    } catch (_) {
      return 'Could not save changes.';
    }
  }

  static Future<String?> remove(String id) async {
    try {
      await broadcasts.doc(id).delete();
      return null;
    } catch (_) {
      return 'Could not remove the broadcast.';
    }
  }

  static Stream<DateTime?> watchLastSeen(String uid) {
    return userDoc(uid).snapshots().map((doc) {
      final ts = doc.data()?['lastBroadcastSeenAt'];
      return ts is Timestamp ? ts.toDate() : null;
    });
  }

  static Future<String?> send({
    required String uid,
    required String title,
    required String message,
  }) async {
    final t = title.trim();
    final m = message.trim();
    final invalid = _validate(t, m);
    if (invalid != null) return invalid;
    try {
      await broadcasts.add({
        'title': t,
        'message': m,
        'sentBy': uid,
        'sentAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (_) {
      return 'Could not send. Make sure you are an admin.';
    }
  }

  static Future<String?> markSeen(String uid, DateTime newest) async {
    try {
      await userDoc(uid).set(
        {'lastBroadcastSeenAt': Timestamp.fromDate(newest)},
        SetOptions(merge: true),
      );
      return null;
    } catch (_) {
      return 'Could not dismiss. Try again.';
    }
  }
}