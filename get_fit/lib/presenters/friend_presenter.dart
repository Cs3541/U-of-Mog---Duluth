import 'package:firebase_auth/firebase_auth.dart';
import '../models/friend_model.dart';
import '../repositories/friend_repository.dart';

class FriendsPresenter {
  final FriendRepository _repo = FriendRepository();

  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<FriendUser>> watchFriends() {
    final uid = currentUid;
    if (uid == null) return Stream.value(const []);
    return _repo.watchFriendIds(uid).asyncMap(_repo.getUsers);
  }

  Stream<List<FriendUser>> watchNewFriends() {
    final uid = currentUid;
    if (uid == null) return Stream.value(const []);
    return _repo.watchUnseenFriendIds(uid).asyncMap(_repo.getUsers);
  }

  Future<String?> dismissNewFriends(List<FriendUser> friends) {
    final uid = currentUid;
    if (uid == null || friends.isEmpty) return Future.value(null);
    return _attempt(
        () => _repo.markFriendsSeen(uid, friends.map((f) => f.uid)),
        'Could not dismiss the alert.');
  }

  Stream<List<FriendRequest>> watchIncoming() {
    final uid = currentUid;
    if (uid == null) return Stream.value(const []);
    return _repo.watchIncoming(uid);
  }

  Stream<List<FriendRequest>> watchOutgoing() {
    final uid = currentUid;
    if (uid == null) return Stream.value(const []);
    return _repo.watchOutgoing(uid);
  }

  Future<List<FriendUser>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final results = await _repo.searchByName(q);
      return results.where((u) => u.uid != currentUid).toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> sendRequest(FriendUser user) async {
    final uid = currentUid;
    if (uid == null) return 'You need to be signed in.';
    try {
      final me = await _repo.getUsers([uid]);
      if (me.isEmpty) return 'Set up your profile first.';
      await _repo.sendRequest(
        from: uid,
        fromName: me.first.displayName,
        to: user.uid,
        toName: user.displayName,
      );
      return null;
    } catch (_) {
      return 'Could not send request. Try again.';
    }
  }

  Future<String?> accept(FriendRequest request) =>
      _attempt(() => _repo.accept(request), 'Could not accept request.');

  Future<String?> decline(FriendRequest request) =>
      _attempt(() => _repo.deleteRequest(request.id), 'Could not decline request.');

  Future<String?> cancel(FriendRequest request) =>
      _attempt(() => _repo.deleteRequest(request.id), 'Could not cancel request.');

  Future<String?> removeFriend(String friendUid) {
    final uid = currentUid;
    if (uid == null) return Future.value('You need to be signed in.');
    return _attempt(
        () => _repo.removeFriend(uid, friendUid), 'Could not remove friend.');
  }

  Future<String?> _attempt(Future<void> Function() action, String error) async {
    try {
      await action();
      return null;
    } catch (_) {
      return error;
    }
  }
}