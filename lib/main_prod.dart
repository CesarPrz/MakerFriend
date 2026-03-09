import 'package:maker_friend/app/bootstrap.dart';
import 'package:maker_friend/core/flavor/flavor_config.dart';
import 'package:maker_friend/firebase_options_prod.dart' as firebase_prod;

Future<void> main() async {
  await bootstrap(
    FlavorConfig.prod,
    firebaseOptions: firebase_prod.DefaultFirebaseOptions.currentPlatform,
  );
}
