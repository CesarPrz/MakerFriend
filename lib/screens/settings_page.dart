import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:maker_friend/features/notifications/cubit/notifications_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _logout() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parametres')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (context, state) {
              final unread = state.unreadCount;
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
