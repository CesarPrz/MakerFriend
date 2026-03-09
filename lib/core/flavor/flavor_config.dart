import 'package:maker_friend/core/flavor/flavor.dart';

class FlavorConfig {
  final Flavor flavor;
  final String appName;
  final bool enableCrashlytics;

  const FlavorConfig({
    required this.flavor,
    required this.appName,
    required this.enableCrashlytics,
  });

  static const FlavorConfig dev = FlavorConfig(
    flavor: Flavor.dev,
    appName: 'MakerFlow Dev',
    enableCrashlytics: false,
  );

  static const FlavorConfig stage = FlavorConfig(
    flavor: Flavor.stage,
    appName: 'MakerFlow Stage',
    enableCrashlytics: true,
  );

  static const FlavorConfig prod = FlavorConfig(
    flavor: Flavor.prod,
    appName: 'MakerFlow',
    enableCrashlytics: true,
  );
}
