import 'package:flutter_test/flutter_test.dart';
import 'package:maker_friend/core/flavor/flavor.dart';
import 'package:maker_friend/core/flavor/flavor_config.dart';

void main() {
  test('dev flavor config', () {
    expect(FlavorConfig.dev.flavor, Flavor.dev);
    expect(FlavorConfig.dev.appName, 'MakerFriend Dev');
    expect(FlavorConfig.dev.enableCrashlytics, false);
  });

  test('prod flavor config', () {
    expect(FlavorConfig.prod.flavor, Flavor.prod);
    expect(FlavorConfig.prod.appName, 'MakerFriend');
    expect(FlavorConfig.prod.enableCrashlytics, true);
  });
}
