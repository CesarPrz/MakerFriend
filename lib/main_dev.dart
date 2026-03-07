import 'package:maker_friend/app/bootstrap.dart';
import 'package:maker_friend/core/flavor/flavor_config.dart';

Future<void> main() async {
  await bootstrap(FlavorConfig.dev);
}
