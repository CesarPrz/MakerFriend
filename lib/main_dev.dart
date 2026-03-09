import 'package:maker_friend/app/bootstrap.dart';
import 'package:maker_friend/core/flavor/flavor_config.dart';
import 'package:maker_friend/firebase_options_dev.dart' as firebase_dev;

Future<void> main() async {
  await bootstrap(
    FlavorConfig.dev,
    firebaseOptions: firebase_dev.DefaultFirebaseOptions.currentPlatform,
  );
}
