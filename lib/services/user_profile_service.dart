import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileService {
  final FirebaseFirestore _db;

  UserProfileService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  /// Crée ou met à jour le profil utilisateur dans Firestore.
  Future<void> upsertCurrentUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();

    final now = FieldValue.serverTimestamp();

    final data = <String, dynamic>{
      'uid': user.uid,
      'displayName': user.displayName,
      'email': user.email,
      'photoUrl': user.photoURL,
      'providerIds': user.providerData.map((p) => p.providerId).toList(),
      'lastLoginAt': now,
    };

    if (!snap.exists) {
      await ref.set({...data, 'createdAt': now});
    } else {
      await ref.set(data, SetOptions(merge: true));
    }
  }
}
