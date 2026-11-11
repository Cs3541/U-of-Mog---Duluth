import 'dart:async';
import '../models/friend_model.dart';
import '../models/profile_model.dart';
import 'auth_presenter.dart';
import 'friend_presenter.dart';
import 'profile_presenter.dart';

enum FriendStatus { self, friends, requestReceived, requestSent, none }

class Relationship {
  const Relationship(this.status, [this.request]);

  final FriendStatus status;
  final FriendRequest? request;
}

class UserProfilePresenter {
  final AuthPresenter _auth = AuthPresenter();
  final ProfilePresenter _profiles = ProfilePresenter();
  final FriendsPresenter _friends = FriendsPresenter();

  String? get currentUid => _auth.getCurrentUserId();

  Stream<Profile> watchProfile(String uid) => _profiles.watchProfile(uid);

  Stream<Relationship> watchRelationship(String uid) {
    if (uid == currentUid) {
      return Stream.value(const Relationship(FriendStatus.self));
    }

    final subs = <StreamSubscription>[];
    List<FriendUser>? friends;
    List<FriendRequest>? incoming;
    List<FriendRequest>? outgoing;
    late final StreamController<Relationship> controller;

    void emit() {
      final f = friends, i = incoming, o = outgoing;
      if (f == null || i == null || o == null) return;
      controller.add(resolve(uid, f, i, o));
    }

    controller = StreamController<Relationship>(
      onListen: () {
        subs.add(_friends.watchFriends().listen((v) {
          friends = v;
          emit();
        }, onError: controller.addError));
        subs.add(_friends.watchIncoming().listen((v) {
          incoming = v;
          emit();
        }, onError: controller.addError));
        subs.add(_friends.watchOutgoing().listen((v) {
          outgoing = v;
          emit();
        }, onError: controller.addError));
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
        subs.clear();
      },
    );
    return controller.stream;
  }

  static Relationship resolve(
    String uid,
    List<FriendUser> friends,
    List<FriendRequest> incoming,
    List<FriendRequest> outgoing,
  ) {
    if (friends.any((f) => f.uid == uid)) {
      return const Relationship(FriendStatus.friends);
    }
    final received = incoming.where((r) => r.from == uid).firstOrNull;
    if (received != null) {
      return Relationship(FriendStatus.requestReceived, received);
    }
    final sent = outgoing.where((r) => r.to == uid).firstOrNull;
    if (sent != null) {
      return Relationship(FriendStatus.requestSent, sent);
    }
    return const Relationship(FriendStatus.none);
  }

  Future<String?> sendRequest(Profile profile) => _friends.sendRequest(
        FriendUser(
          uid: profile.uid,
          displayName: profile.displayName,
          photo: profile.photo,
        ),
      );

  Future<String?> accept(FriendRequest request) => _friends.accept(request);

  Future<String?> decline(FriendRequest request) => _friends.decline(request);

  Future<String?> cancel(FriendRequest request) => _friends.cancel(request);

  Future<String?> removeFriend(String uid) => _friends.removeFriend(uid);
}