import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthState {
  final User? user;
  const AuthState(this.user);

  bool get isAuthenticated => user != null;
}

class AuthCubit extends Cubit<AuthState> {
  final FirebaseAuth _auth;
  StreamSubscription<User?>? _sub;

  AuthCubit({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance,
      super(AuthState((auth ?? FirebaseAuth.instance).currentUser)) {
    _sub = _auth.authStateChanges().listen((u) => emit(AuthState(u)));
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
