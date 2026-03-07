import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maker_friend/features/notifications/cubit/notifications_cubit.dart';
import 'package:maker_friend/repositories/notification_repository.dart';

class _FakeNotificationRepository extends NotificationRepository {
  final Stream<int> stream;
  _FakeNotificationRepository(this.stream);

  @override
  Stream<int> watchUnreadCount() => stream;
}

void main() {
  test('emits unread count from repository stream', () async {
    final controller = StreamController<int>();
    final cubit = NotificationsCubit(_FakeNotificationRepository(controller.stream));

    controller.add(4);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(cubit.state.unreadCount, 4);
    expect(cubit.state.loading, false);

    await cubit.close();
    await controller.close();
  });
}
