import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maker_friend/models/app_user_model.dart';

class UserRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  UserRepository({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// Stream temps réel du user (Firestore)
  Stream<AppUser?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return AppUser.fromJson(data);
    });
  }

  /// Stream temps réel du user connecté
  Stream<AppUser?> watchCurrentUser() {
    return _auth.authStateChanges().switchMap((firebaseUser) {
      if (firebaseUser == null) return Stream.value(null);
      return watchUser(firebaseUser.uid);
    });
  }

  Future<List<AppUser>> searchUsersByDisplayName(
    String query, {
    int limit = 50,
  }) async {
    final queryLower = query.trim().toLowerCase();
    if (queryLower.isEmpty) return [];

    final snap = await _users.limit(limit).get();

    return snap.docs
        .map((d) => AppUser.fromJson(d.data()))
        .where(
          (u) =>
              (u.displayName ?? '').toLowerCase().contains(queryLower) ||
              u.uid.toLowerCase().contains(queryLower),
        )
        .toList();
  }

  /// Lecture 1 fois
  Future<AppUser?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return AppUser.fromJson(data);
  }

  /// Crée / MAJ le profil Firestore à partir du user FirebaseAuth
  Future<void> upsertFromFirebaseAuthUser(User firebaseUser) async {
    final ref = _users.doc(firebaseUser.uid);
    final snap = await ref.get();

    final now = FieldValue.serverTimestamp();

    final data = <String, dynamic>{
      'uid': firebaseUser.uid,
      'displayName': firebaseUser.displayName,
      'email': firebaseUser.email,
      'photoUrl': firebaseUser.photoURL,
      'providerIds': firebaseUser.providerData
          .map((p) => p.providerId)
          .toList(),
      'lastLoginAt': now,
    };

    if (!snap.exists) {
      await ref.set({...data, 'createdAt': now});
    } else {
      await ref.set(data, SetOptions(merge: true));
    }
  }

  /// Patch partiel (ex: changer displayName côté app)
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _users.doc(uid).set(data, SetOptions(merge: true));
  }

  Stream<bool> watchIsFollowing({
    required String currentUid,
    required String targetUid,
  }) {
    if (currentUid.isEmpty || targetUid.isEmpty || currentUid == targetUid) {
      return Stream.value(false);
    }

    return _users
        .doc(currentUid)
        .collection('following')
        .doc(targetUid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Le client écrit seulement users/{me}/following/{target}.
  /// La synchronisation followers + compteurs est gérée par Cloud Function.
  Future<void> followUser({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid.isEmpty || targetUid.isEmpty || currentUid == targetUid) {
      return;
    }

    await _users.doc(currentUid).collection('following').doc(targetUid).set({
      'uid': targetUid,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unfollowUser({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid.isEmpty || targetUid.isEmpty || currentUid == targetUid) {
      return;
    }

    await _users.doc(currentUid).collection('following').doc(targetUid).delete();
  }
}

/// Petit helper Stream sans dépendance externe.
/// Si tu utilises rxdart, tu peux remplacer ça par switchMap direct.
extension _SwitchMapExt<T> on Stream<T> {
  Stream<R> switchMap<R>(Stream<R> Function(T value) mapper) {
    late StreamSubscription<T> sub;
    StreamSubscription<R>? innerSub;
    final controller = StreamController<R>();

    sub = listen(
      (value) async {
        await innerSub?.cancel();
        innerSub = mapper(
          value,
        ).listen(controller.add, onError: controller.addError, onDone: () {});
      },
      onError: controller.addError,
      onDone: () async {
        await innerSub?.cancel();
        await controller.close();
      },
    );

    controller.onCancel = () async {
      await innerSub?.cancel();
      await sub.cancel();
    };

    return controller.stream;
  }
}
