import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maker_friend/screens/my_projects_page.dart';
import 'services/auth_service.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data == null) return LoginPage();
        if (snap.data != null) {
          // fire-and-forget (pas besoin de bloquer l'UI)
          AuthService().signInWithGoogle; // ❌ non, on ne relog pas
        }
        return const MyProjectsPage();
      },
    );
  }
}

class HomePage extends StatelessWidget {
  final AuthService authService;
  const HomePage({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil'),
        actions: [
          IconButton(
            onPressed: authService.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Connecté: ${user?.displayName ?? user?.email ?? user?.uid}',
        ),
      ),
    );
  }
}
