import 'package:firebase_auth/firebase_auth.dart';
import '../models/broadcast_model.dart';

class BroadcastPresenter {
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  Stream<bool> watchIsAdmin() {
    final uid = currentUid;
    if (uid == null) return Stream.value(false);
    return BroadcastRules.watchIsAdmin(uid);
  }

  Stream<List<Broadcast>> watchRecent() => BroadcastRules.watchRecent();

  Stream<List<Broadcast>> watchHistory() => BroadcastRules.watchAll();

  Future<String?> edit(String id, String title, String message) =>
      BroadcastRules.edit(id: id, title: title, message: message);

  Future<String?> remove(String id) => BroadcastRules.remove(id);

  Stream<DateTime?> watchLastSeen() {
    final uid = currentUid;
    if (uid == null) return Stream.value(null);
    return BroadcastRules.watchLastSeen(uid);
  }

  List<Broadcast> unseen(List<Broadcast> all, DateTime? lastSeen) {
    return all
        .where((b) =>
            b.sentAt != null &&
            (lastSeen == null || b.sentAt!.isAfter(lastSeen)))
        .toList();
  }

  Future<String?> send(String title, String message) {
    final uid = currentUid;
    if (uid == null) return Future.value('You are not signed in.');
    return BroadcastRules.send(uid: uid, title: title, message: message);
  }

  Future<String?> dismiss(List<Broadcast> shown) {
    final uid = currentUid;
    if (uid == null || shown.isEmpty) return Future.value(null);
    final newest = shown
        .map((b) => b.sentAt!)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return BroadcastRules.markSeen(uid, newest);
  }
}