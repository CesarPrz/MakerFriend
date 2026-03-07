import 'package:flutter_test/flutter_test.dart';
import 'package:maker_friend/utils/relative_time.dart';

void main() {
  group('formatRelativeTime', () {
    test('returns instant for null', () {
      expect(formatRelativeTime(null), 'A l\'instant');
    });

    test('returns minutes', () {
      final now = DateTime.now();
      expect(
        formatRelativeTime(now.subtract(const Duration(minutes: 5))),
        'Il y a 5 min',
      );
    });

    test('returns hours', () {
      final now = DateTime.now();
      expect(
        formatRelativeTime(now.subtract(const Duration(hours: 3))),
        'Il y a 3 h',
      );
    });

    test('returns yesterday', () {
      final now = DateTime.now();
      expect(
        formatRelativeTime(now.subtract(const Duration(days: 1))),
        'Hier',
      );
    });
  });
}
