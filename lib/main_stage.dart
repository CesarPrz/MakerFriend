import 'package:maker_friend/app/bootstrap.dart';
import 'package:maker_friend/core/flavor/flavor_config.dart';
import 'package:maker_friend/firebase_options_stage.dart' as firebase_stage;

Future<void> main() async {
  await bootstrap(
    FlavorConfig.stage,
    firebaseOptions: firebase_stage.DefaultFirebaseOptions.currentPlatform,
  );
}
