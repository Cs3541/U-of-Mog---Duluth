import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

class FriendUser {
  const FriendUser({required this.uid, required this.displayName, this.photo});

  final String uid;
  final String displayName;
  final Uint8List? photo;

  factory FriendUser.fromProfileDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return FriendUser(
      uid: doc.id,
      displayName: d['displayName'] as String? ?? 'Unknown',
      photo: (d['photo'] as Blob?)?.bytes,
    );
  }
}

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.from,
    required this.to,
    required this.fromName,
    required this.toName,
  });

  final String id;
  final String from;
  final String to;
  final String fromName;
  final String toName;

  static String idFor(String from, String to) => '${from}_$to';

  factory FriendRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return FriendRequest(
      id: doc.id,
      from: d['from'] as String? ?? '',
      to: d['to'] as String? ?? '',
      fromName: d['fromName'] as String? ?? 'Unknown',
      toName: d['toName'] as String? ?? 'Unknown',
    );
  }
}