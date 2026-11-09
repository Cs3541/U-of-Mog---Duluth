import 'package:firebase_auth/firebase_auth.dart';
import '../models/exp_model.dart';
import '../models/feed_model.dart';

class HomePresenter {
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  Stream<ExpStatus> watchExp(String uid) => ExpRules.watchExp(uid);

  Stream<List<FeedItem>> watchFeed(String uid) => FeedRules.watchRecent(uid);

  Future<void> dismiss(String uid, String itemId) =>
      FeedRules.dismiss(uid, itemId);

  Future<void> dismissAll(String uid, Iterable<String> itemIds) =>
      FeedRules.dismissAll(uid, itemIds);
}