import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'badge_model.dart';
import 'exp_model.dart';

class Profile {
  final String uid;
  final String displayName;
  final Uint8List? photo;
  final int totalExp;

  const Profile({
    required this.uid,
    required this.displayName,
    required this.totalExp,
    this.photo,
  });

  int get level => ExpRules.levelForExp(totalExp);

  factory Profile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final photo = d['photo'];
    return Profile(
      uid: doc.id,
      displayName: (d['displayName'] as String?) ?? ProfileRules.defaultName,
      photo: photo is Blob ? photo.bytes : null,
      totalExp: (d['totalExp'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProfileRules {
  static const int maxNameLength = 30;
  static const int maxPhotoBytes = 300 * 1024;
  static const String defaultName = 'Get Fit user';

  static CollectionReference<Map<String, dynamic>> get collection =>
      FirebaseFirestore.instance.collection('profiles');

  static DocumentReference<Map<String, dynamic>> profileDoc(String uid) =>
      collection.doc(uid);

  static DocumentReference<Map<String, dynamic>> friendBadgesDoc(String uid) =>
      profileDoc(uid).collection('friendsOnly').doc('badges');

  static Stream<Map<String, DateTime?>> watchFriendBadges(String uid) =>
      friendBadgesDoc(uid)
          .snapshots()
          .map((s) => BadgeRules.parseEarned(s.data()));

  static DocumentReference<Map<String, dynamic>> activityDoc(String uid) =>
      profileDoc(uid).collection('friendsOnly').doc('activity');

  static Stream<DateTime?> watchLastWorkout(String uid) =>
      activityDoc(uid).snapshots().map((s) {
        final ts = s.data()?['lastWorkoutAt'];
        return ts is Timestamp ? ts.toDate() : null;
      });

  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
      watchLastWorkoutSync(String uid) {
    Timestamp? synced;
    return ExpRules.userDoc(uid)
        .collection('workoutLogs')
        .orderBy('completedAt', descending: true)
        .limit(1)
        .snapshots()
        .listen(
      (snap) async {
        if (snap.docs.isEmpty) return;
        final ts = snap.docs.first.data()['completedAt'];
        if (ts is! Timestamp || ts == synced) return;
        try {
          await activityDoc(uid).set({'lastWorkoutAt': ts});
          synced = ts;
        } catch (e) {
          debugPrint('Could not sync last workout: $e');
        }
      },
      onError: (Object e) => debugPrint('Last workout sync stopped: $e'),
    );
  }

  static String? validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Enter a display name.';
    if (trimmed.length > maxNameLength) {
      return 'Display name can be up to $maxNameLength characters.';
    }
    return null;
  }

  static Stream<Profile> watchProfile(String uid) =>
      profileDoc(uid).snapshots().map(Profile.fromDoc);

  static Stream<List<Profile>> watchTopProfiles({int limit = 50}) {
    return collection
        .orderBy('totalExp', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(Profile.fromDoc).toList());
  }

  static Future<void> ensureProfile(String uid, {String? displayName}) async {
    final db = FirebaseFirestore.instance;
    final userRef = db.collection('users').doc(uid);
    final ref = profileDoc(uid);

    await db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final profileSnap = await tx.get(ref);

      final data = <String, dynamic>{
        'totalExp': (userSnap.data()?['totalExp'] as num?)?.toInt() ?? 0,
      };
      if (profileSnap.data()?['displayName'] is! String) {
        final name = displayName?.trim() ?? '';
        data['displayName'] =
            validateName(name) == null ? name : defaultName;
      }
      tx.set(ref, data, SetOptions(merge: true));
    });
  }

  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
      watchBadgeSync(String uid) {
    var synced = <String>{};
    var migrated = false;
    return ExpRules.userDoc(uid).snapshots().listen(
      (snap) async {
        final data = snap.data();
        if (data == null) return;
        if (migrated && synced.containsAll(BadgeRules.earnedIds(data))) return;
        try {
          synced = await syncBadges(uid, data);
          migrated = true;
        } catch (e) {
          debugPrint('Could not sync badges: $e');
        }
      },
      onError: (Object e) => debugPrint('Badge sync stopped: $e'),
    );
  }

  static Future<Set<String>> syncBadges(
    String uid,
    Map<String, dynamic> userData,
  ) {
    final earned = BadgeRules.earnedIds(userData);
    final knownIds = BadgeRules.allBadges.map((b) => b.id).toSet();
    final joinedAt = userData['joinedAt'];
    final badgeRef = friendBadgesDoc(uid);
    final profileRef = profileDoc(uid);

    return FirebaseFirestore.instance.runTransaction((tx) async {
      final badgeSnap = await tx.get(badgeRef);
      final profileSnap = await tx.get(profileRef);

      final have = (badgeSnap.data() ?? const {}).keys.toSet();
      final legacy = profileSnap.data()?['badges'];
      final toWrite = <String, dynamic>{};

      if (legacy is Map) {
        for (final e in legacy.entries) {
          final id = e.key;
          if (id is String &&
              knownIds.contains(id) &&
              !have.contains(id) &&
              e.value is Timestamp) {
            toWrite[id] = e.value;
          }
        }
      }

      for (final id in earned) {
        if (have.contains(id) || toWrite.containsKey(id)) continue;
        toWrite[id] = id == 'new_user' && joinedAt is Timestamp
            ? joinedAt
            : FieldValue.serverTimestamp();
      }

      if (toWrite.isNotEmpty) {
        tx.set(badgeRef, toWrite, SetOptions(merge: true));
      }
      if (legacy != null) {
        tx.update(profileRef, {'badges': FieldValue.delete()});
      }
      return {...have, ...toWrite.keys};
    });
  }

  static Future<String?> updateDisplayName(String uid, String name) async {
    final error = validateName(name);
    if (error != null) return error;
    try {
      await profileDoc(uid).set(
        {'displayName': name.trim()},
        SetOptions(merge: true),
      );
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? 'Could not save your display name.';
    }
  }

  static Future<String?> setPhoto(String uid, Uint8List bytes) async {
    if (bytes.length > maxPhotoBytes) {
      return 'That photo is too large. Try a different one.';
    }
    try {
      await profileDoc(uid).set(
        {'photo': Blob(bytes)},
        SetOptions(merge: true),
      );
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? 'Could not save your photo.';
    }
  }

  static Future<String?> removePhoto(String uid) async {
    try {
      await profileDoc(uid).set(
        {'photo': FieldValue.delete()},
        SetOptions(merge: true),
      );
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? 'Could not remove your photo.';
    }
  }
}