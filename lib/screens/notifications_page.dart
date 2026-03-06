import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maker_friend/models/notification_model.dart';
import 'package:maker_friend/repositories/notification_repository.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = NotificationRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<List<AppNotification>>(
        stream: repo.watchMyNotifications(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('Aucune notification pour le moment.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final n = items[i];
              return _NotificationTile(
                notification: n,
                onTap: () async {
                  await repo.markAsRead(n.id);
                  if (!context.mounted) return;
                  _openNotification(context, n);
                },
              );
            },
          );
        },
      ),
    );
  }

  void _openNotification(BuildContext context, AppNotification n) {
    switch (n.type) {
      case AppNotificationType.newFollower:
        context.push('/u/${n.actorUid}');
        break;
      case AppNotificationType.projectLike:
        if ((n.projectId ?? '').isNotEmpty) {
          context.push('/projects/${n.projectId}');
        }
        break;
      case AppNotificationType.postComment:
        if ((n.projectId ?? '').isNotEmpty && (n.itemId ?? '').isNotEmpty) {
          context.push(
            '/my-projects/${n.projectId}/timeline/${n.itemId}',
            extra: n.itemTitle ?? 'Post',
          );
        }
        break;
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = _label(notification);
    return Material(
      color: notification.isRead
          ? Colors.transparent
          : Theme.of(context).colorScheme.secondary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          backgroundImage: (notification.actorPhotoUrl ?? '').isNotEmpty
              ? NetworkImage(notification.actorPhotoUrl!)
              : null,
          child: (notification.actorPhotoUrl ?? '').isNotEmpty
              ? null
              : Icon(_icon(notification.type)),
        ),
        title: Text(text),
        subtitle: Text(_dateLabel(notification.createdAt)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  IconData _icon(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.projectLike:
        return Icons.favorite;
      case AppNotificationType.newFollower:
        return Icons.person_add_alt_1;
      case AppNotificationType.postComment:
        return Icons.mode_comment_outlined;
    }
  }

  String _label(AppNotification n) {
    final actor = (n.actorName ?? '').trim().isEmpty
        ? 'Quelqu\'un'
        : n.actorName!.trim();
    switch (n.type) {
      case AppNotificationType.projectLike:
        final projectTitle = (n.projectTitle ?? '').trim();
        if (projectTitle.isEmpty) return '$actor a like ton projet.';
        return '$actor a like ton projet "$projectTitle".';
      case AppNotificationType.newFollower:
        return '$actor te suit maintenant.';
      case AppNotificationType.postComment:
        final itemTitle = (n.itemTitle ?? '').trim();
        if (itemTitle.isEmpty) return '$actor a commente ton post.';
        return '$actor a commente ton post "$itemTitle".';
    }
  }

  String _dateLabel(DateTime? dt) {
    if (dt == null) return 'A l\'instant';
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $hh:$mm';
  }
}
