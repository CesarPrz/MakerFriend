import 'package:flutter_test/flutter_test.dart';
import 'package:maker_friend/core/flavor/flavor_config.dart';

void main() {
  test('default prod app name is MakerFriend', () {
    expect(FlavorConfig.prod.appName, 'MakerFriend');
  });
}
