import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:maker_friend/app/app.dart';
import 'package:maker_friend/core/flavor/flavor_config.dart';
import 'package:maker_friend/firebase_options.dart';
import 'package:maker_friend/services/push_notification_service.dart';

Future<void> bootstrap(FlavorConfig flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await PushNotificationService().init();
  runApp(MakerFriendApp(flavor: flavor));
}
