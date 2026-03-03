import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../repositories/user_repository.dart';

class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final UserRepository _userRepo;

  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    UserRepository? userRepo,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn(),
       _userRepo = userRepo ?? UserRepository();

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);

    final user = userCredential.user;

    if (user != null) {
      try {
        await _userRepo.upsertFromFirebaseAuthUser(user);
        print("✅ Firestore user created/updated");
      } catch (e) {
        print("❌ Firestore error: $e");
      }
    }

    return userCredential;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
