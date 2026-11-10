import 'package:cloud_firestore/cloud_firestore.dart';

enum FeedType { exp, levelUp, badge }

class FeedItem {
  final String id;
  final FeedType type;
  final String title;
  final String subtitle;

  final DateTime? achievedAt;

  final bool timeUnknown;

  const FeedItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.achievedAt,
    this.timeUnknown = false,
  });

  factory FeedItem.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final ts = d['occurredAt'] ?? d['achievedAt'];
    return FeedItem(
      id: doc.id,
      type: FeedType.values.firstWhere(
        (t) => t.name == d['type'],
        orElse: () => FeedType.exp,
      ),
      title: (d['title'] as String?) ?? '',
      subtitle: (d['subtitle'] as String?) ?? '',
      achievedAt: ts is Timestamp ? ts.toDate() : null,
      timeUnknown: d['timeUnknown'] == true,
    );
  }
}

class FeedRules {
  static CollectionReference<Map<String, dynamic>> feedFor(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('feed');

  static Map<String, dynamic> entry({
    required FeedType type,
    required String title,
    required String subtitle,
    DateTime? occurredAt,
    bool timeUnknown = false,
  }) =>
      {
        'type': type.name,
        'title': title,
        'subtitle': subtitle,
        'achievedAt': FieldValue.serverTimestamp(),
        if (occurredAt != null) 'occurredAt': Timestamp.fromDate(occurredAt),
        if (timeUnknown) 'timeUnknown': true,
      };

  static Stream<List<FeedItem>> watchRecent(String uid, {int limit = 20}) {
    return feedFor(uid)
        .orderBy('achievedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(FeedItem.fromDoc).toList());
  }

  static Future<void> dismiss(String uid, String id) =>
      feedFor(uid).doc(id).delete();

  static Future<void> dismissAll(String uid, Iterable<String> ids) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final id in ids) {
      batch.delete(feedFor(uid).doc(id));
    }
    await batch.commit();
  }
}