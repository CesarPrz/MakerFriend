import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:maker_friend/features/notifications/cubit/notifications_cubit.dart';

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, state) {
        final unread = state.unreadCount;
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
