import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageService {
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  StorageService({FirebaseStorage? storage, FirebaseAuth? auth})
    : _storage = storage ?? FirebaseStorage.instance,
      _auth = auth ?? FirebaseAuth.instance;

  Future<String> uploadProjectTimelineImage({
    required String projectId,
    required File file,
  }) async {
    final user = _auth.currentUser!;
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();

    // Chemin conseillé
    final ref = _storage.ref(
      'my-projects/$projectId/timeline/${user.uid}/$fileName.jpg',
    );

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {'projectId': projectId, 'uid': user.uid},
    );

    final task = await ref.putFile(file, metadata);
    return task.ref.getDownloadURL();
  }

  Future<String> uploadProjectCover({
    required String projectId,
    required File file,
  }) async {
    final user = _auth.currentUser!;
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();

    final ref = _storage.ref(
      'projects/$projectId/cover/${user.uid}_$fileName.jpg',
    );

    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return task.ref.getDownloadURL();
  }
}
