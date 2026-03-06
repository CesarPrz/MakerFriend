import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:maker_friend/repositories/notification_repository.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _logout() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final notificationsRepo = NotificationRepository();
    return Scaffold(
      appBar: AppBar(title: const Text('Parametres')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StreamBuilder<int>(
            stream: notificationsRepo.watchUnreadCount(),
            builder: (context, snap) {
              final unread = snap.data ?? 0;
              return ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notifications'),
                subtitle: unread > 0 ? Text('$unread non lues') : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/notifications'),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Modifier le profil'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/profile'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme'),
            subtitle: const Text('Systeme / Clair / Sombre'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/theme'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Deconnexion'),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}
