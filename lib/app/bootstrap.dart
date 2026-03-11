import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:maker_friend/app/app.dart';
import 'package:maker_friend/core/flavor/flavor_config.dart';
import 'package:maker_friend/services/push_notification_service.dart';

Future<FirebaseApp> _initFirebaseOnce(FirebaseOptions options) async {
  if (Firebase.apps.isNotEmpty) {
    return Firebase.app();
  }

  try {
    return await Firebase.initializeApp(options: options);
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      return Firebase.app();
    }
    rethrow;
  }
}

Future<void> bootstrap(
  FlavorConfig flavor, {
  required FirebaseOptions firebaseOptions,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initFirebaseOnce(firebaseOptions);
  await PushNotificationService().init();
  runApp(MakerFlowApp(flavor: flavor));
}
