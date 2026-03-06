import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PushNotificationService {
  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  PushNotificationService({
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FirebaseFirestore? db,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _db = db ?? FirebaseFirestore.instance;

  Future<void> init() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await _saveCurrentToken();

    _messaging.onTokenRefresh.listen((token) async {
      await _saveToken(token);
    });

    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await _saveCurrentToken();
      }
    });
  }

  Future<void> _saveCurrentToken() async {
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    await _db.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastPushTokenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
