import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:maker_friend/models/app_user_model.dart';
import 'package:maker_friend/repositories/notification_repository.dart';

class UserRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final NotificationRepository _notifications;

  UserRepository({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    NotificationRepository? notifications,
  }) : _db = db ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
       _notifications =
           notifications ?? NotificationRepository(db: db, auth: auth);

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _projects =>
      _db.collection('projects');

  /// Stream temps réel du user (Firestore)
  Stream<AppUser?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return AppUser.fromJson(data, fallbackUid: doc.id);
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
    return AppUser.fromJson(data, fallbackUid: doc.id);
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

    final ownerUpdate = <String, dynamic>{};
    if (data.containsKey('displayName')) {
      ownerUpdate['ownerDisplayName'] = data['displayName'];
    }
    if (data.containsKey('photoUrl')) {
      ownerUpdate['ownerPhotoUrl'] = data['photoUrl'];
    }
    if (ownerUpdate.isEmpty) return;

    final projectsSnap = await _projects.where('ownerUid', isEqualTo: uid).get();
    if (projectsSnap.docs.isEmpty) return;

    WriteBatch batch = _db.batch();
    var ops = 0;
    for (final doc in projectsSnap.docs) {
      batch.set(doc.reference, ownerUpdate, SetOptions(merge: true));
      ops++;

      if (ops == 450) {
        await batch.commit();
        batch = _db.batch();
        ops = 0;
      }
    }
    if (ops > 0) {
      await batch.commit();
    }
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

  Stream<List<AppUser>> watchFollowingUsers(String uid) {
    return _watchUsersFromSubcollection(uid: uid, subcollection: 'following');
  }

  Stream<List<AppUser>> watchFollowersUsers(String uid) {
    return _watchUsersFromSubcollection(uid: uid, subcollection: 'followers');
  }

  Stream<List<AppUser>> _watchUsersFromSubcollection({
    required String uid,
    required String subcollection,
  }) {
    if (uid.isEmpty) return Stream.value(const []);

    final relationRef = _users.doc(uid).collection(subcollection);
    late StreamSubscription<QuerySnapshot<Map<String, dynamic>>> relationSub;
    final userSubs = <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
    final usersByUid = <String, AppUser>{};
    final controller = StreamController<List<AppUser>>();

    void emit() {
      final users = usersByUid.values.toList()
        ..sort((a, b) {
          final an = (a.displayName ?? a.uid).toLowerCase();
          final bn = (b.displayName ?? b.uid).toLowerCase();
          return an.compareTo(bn);
        });
      controller.add(users);
    }

    Future<void> rebuildUserSubs(List<String> uids) async {
      for (final sub in userSubs.values) {
        await sub.cancel();
      }
      userSubs.clear();
      usersByUid.clear();

      if (uids.isEmpty) {
        emit();
        return;
      }

      for (final targetUid in uids) {
        final sub = _users.doc(targetUid).snapshots().listen(
          (doc) {
            final data = doc.data();
            if (!doc.exists || data == null) {
              usersByUid.remove(targetUid);
            } else {
              usersByUid[targetUid] = AppUser.fromJson(data);
            }
            emit();
          },
          onError: controller.addError,
        );
        userSubs[targetUid] = sub;
      }
    }

    relationSub = relationRef.snapshots().listen(
      (snap) {
        final uids = snap.docs.map((d) => d.id).toList();
        rebuildUserSubs(uids);
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await relationSub.cancel();
      for (final sub in userSubs.values) {
        await sub.cancel();
      }
    };

    return controller.stream;
  }

  Future<void> followUser({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid.isEmpty || targetUid.isEmpty || currentUid == targetUid) {
      return;
    }

    final meFollowingRef = _users
        .doc(currentUid)
        .collection('following')
        .doc(targetUid);
    final targetFollowerRef = _users
        .doc(targetUid)
        .collection('followers')
        .doc(currentUid);
    var created = false;
    await _db.runTransaction((tx) async {
      final followingSnap = await tx.get(meFollowingRef);
      if (followingSnap.exists) return;

      created = true;
      final now = FieldValue.serverTimestamp();
      tx.set(meFollowingRef, {'uid': targetUid, 'createdAt': now});
      tx.set(targetFollowerRef, {'uid': currentUid, 'createdAt': now});
    });

    if (!created) return;

    final meDoc = await _users.doc(currentUid).get();
    final me = meDoc.data();
    await _notifications.createNotification(
      recipientUid: targetUid,
      type: 'new_follower',
      actorUid: currentUid,
      actorName: me?['displayName'] as String?,
      actorPhotoUrl: me?['photoUrl'] as String?,
    );
  }

  Future<void> unfollowUser({
    required String currentUid,
    required String targetUid,
  }) async {
    if (currentUid.isEmpty || targetUid.isEmpty || currentUid == targetUid) {
      return;
    }

    final meFollowingRef = _users
        .doc(currentUid)
        .collection('following')
        .doc(targetUid);
    final targetFollowerRef = _users
        .doc(targetUid)
        .collection('followers')
        .doc(currentUid);

    await _db.runTransaction((tx) async {
      tx.delete(meFollowingRef);
      tx.delete(targetFollowerRef);
    });
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
