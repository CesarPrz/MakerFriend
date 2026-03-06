import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maker_friend/models/notification_model.dart';

class NotificationRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  NotificationRepository({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _notificationsCol(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  Stream<List<AppNotification>> watchMyNotifications({int limit = 100}) {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return Stream.value(const []);

    return _notificationsCol(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(AppNotification.fromDoc).toList());
  }

  Stream<int> watchUnreadCount() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return Stream.value(0);

    return _notificationsCol(uid)
        .where('readAt', isNull: true)
        .snapshots()
        .map((snap) => snap.size);
  }

  Future<void> markAsRead(String notificationId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty || notificationId.isEmpty) return;

    await _notificationsCol(uid).doc(notificationId).set({
      'readAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markAllAsRead() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    final unreadSnap = await _notificationsCol(uid)
        .where('readAt', isNull: true)
        .get();
    if (unreadSnap.docs.isEmpty) return;

    WriteBatch batch = _db.batch();
    var ops = 0;
    for (final doc in unreadSnap.docs) {
      batch.set(doc.reference, {
        'readAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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

  Future<void> createNotification({
    required String recipientUid,
    required String type,
    required String actorUid,
    String? actorName,
    String? actorPhotoUrl,
    String? projectId,
    String? projectTitle,
    String? itemId,
    String? itemTitle,
  }) async {
    if (recipientUid.isEmpty || actorUid.isEmpty) return;
    if (recipientUid == actorUid) return;

    await _notificationsCol(recipientUid).add({
      'type': type,
      'recipientUid': recipientUid,
      'actorUid': actorUid,
      'actorName': actorName,
      'actorPhotoUrl': actorPhotoUrl,
      'projectId': projectId,
      'projectTitle': projectTitle,
      'itemId': itemId,
      'itemTitle': itemTitle,
      'createdAt': FieldValue.serverTimestamp(),
      'readAt': null,
    });
  }
}
