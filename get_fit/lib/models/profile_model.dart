import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
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