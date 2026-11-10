import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/profile_model.dart';

class ProfilePresenter {
  final ImagePicker _picker = ImagePicker();

  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  Stream<Profile> watchProfile(String uid) => ProfileRules.watchProfile(uid);

  Future<String?> saveDisplayName(String uid, String name) =>
      ProfileRules.updateDisplayName(uid, name);

  Future<String?> takePhoto(String uid) => _pickPhoto(uid, ImageSource.camera);

  Future<String?> uploadPhoto(String uid) =>
      _pickPhoto(uid, ImageSource.gallery);

  Future<String?> removePhoto(String uid) => ProfileRules.removePhoto(uid);

  Future<String?> _pickPhoto(String uid, ImageSource source) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 70,
      );
    } catch (_) {
      return 'Could not open the camera or photos.';
    }
    if (file == null) return null;
    return ProfileRules.setPhoto(uid, await file.readAsBytes());
  }
}