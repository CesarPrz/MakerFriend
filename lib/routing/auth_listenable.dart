import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Permet à GoRouter de se rafraîchir quand l’état Firebase Auth change.
class AuthListenable extends ChangeNotifier {
  late final StreamSubscription<User?> _sub;

  AuthListenable() {
    _sub = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
