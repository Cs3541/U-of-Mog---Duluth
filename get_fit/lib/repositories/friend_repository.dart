import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friend_model.dart';

class FriendRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('friendRequests');

  CollectionReference<Map<String, dynamic>> _friends(String uid) =>
      _db.collection('users').doc(uid).collection('friends');

  Stream<Set<String>> watchFriendIds(String uid) {
    return _friends(uid)
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toSet());
  }

  Stream<List<String>> watchUnseenFriendIds(String uid) {
    return _friends(uid)
        .where('seen', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toList());
  }

  Future<void> markFriendsSeen(String uid, Iterable<String> friendUids) {
    final batch = _db.batch();
    for (final f in friendUids) {
      batch.update(_friends(uid).doc(f), {'seen': true});
    }
    return batch.commit();
  }

  Stream<List<FriendRequest>> watchIncoming(String uid) {
    return _requests
        .where('to', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.map(FriendRequest.fromDoc).toList());
  }

  Stream<List<FriendRequest>> watchOutgoing(String uid) {
    return _requests
        .where('from', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.map(FriendRequest.fromDoc).toList());
  }

  Future<List<FriendUser>> getUsers(Iterable<String> uids) async {
    final docs = await Future.wait(
      uids.map((u) => _db.collection('profiles').doc(u).get()),
    );
    return docs.where((d) => d.exists).map(FriendUser.fromProfileDoc).toList();
  }

  Future<List<FriendUser>> searchByName(String query) async {
    final snap = await _db
        .collection('profiles')
        .orderBy('displayName')
        .startAt([query])
        .endAt(['$query\uf8ff'])
        .limit(20)
        .get();
    return snap.docs.map(FriendUser.fromProfileDoc).toList();
  }

  Future<void> sendRequest({
    required String from,
    required String fromName,
    required String to,
    required String toName,
  }) {
    return _requests.doc(FriendRequest.idFor(from, to)).set({
      'from': from,
      'to': to,
      'fromName': fromName,
      'toName': toName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> accept(FriendRequest request) {
    final batch = _db.batch();
    batch.set(_friends(request.to).doc(request.from),
        {'since': FieldValue.serverTimestamp(), 'seen': false});
    batch.set(_friends(request.from).doc(request.to),
        {'since': FieldValue.serverTimestamp(), 'seen': false});
    batch.delete(_requests.doc(request.id));
    return batch.commit();
  }

  Future<void> deleteRequest(String id) => _requests.doc(id).delete();

  Future<void> removeFriend(String uid, String friendUid) {
    final batch = _db.batch();
    batch.delete(_friends(uid).doc(friendUid));
    batch.delete(_friends(friendUid).doc(uid));
    return batch.commit();
  }
}