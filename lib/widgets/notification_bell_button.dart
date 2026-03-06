import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maker_friend/repositories/notification_repository.dart';

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = NotificationRepository();
    return StreamBuilder<int>(
      stream: repo.watchUnreadCount(),
      builder: (context, snap) {
        final unread = snap.data ?? 0;
        return IconButton(
          tooltip: 'Notifications',
          onPressed: () => context.push('/settings/notifications'),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined),
              if (unread > 0)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 0.8),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
