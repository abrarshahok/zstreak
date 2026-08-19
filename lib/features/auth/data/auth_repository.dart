import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thin wrapper around Firebase Auth + Google Sign-In.
///
/// Only three sign-in paths exist (spec Section 2): anonymous (guest),
/// Google, and email/password. Stage 6 adds account linking — upgrading
/// the current anonymous user to a permanent one — on top of these.
class AuthRepository {
  AuthRepository({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<void> signInAnonymously() => _firebaseAuth.signInAnonymously();

  /// Returns null without throwing if the user cancels the Google picker
  /// — cancellation is not an error (Section 3, screen 2).
  Future<UserCredential?> signInWithGoogle() async {
    final credential = await _getGoogleCredential();
    if (credential == null) return null;
    return _firebaseAuth.signInWithCredential(credential);
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) => _firebaseAuth.signInWithEmailAndPassword(
    email: email,
    password: password,
  );

  Future<void> registerWithEmail({
    required String email,
    required String password,
  }) => _firebaseAuth.createUserWithEmailAndPassword(
    email: email,
    password: password,
  );

  /// Upgrades the current anonymous user in place (spec Section 3a) — the
  /// uid never changes, so Firestore docs written after this call are
  /// already correctly scoped. Returns null if the user cancels the
  /// Google picker. Throws [FirebaseAuthException] with code
  /// `credential-already-in-use` if that Google account already has a
  /// ZStreak account — callers must offer the sign-in-and-merge path.
  Future<UserCredential?> linkWithGoogle() async {
    final credential = await _getGoogleCredential();
    if (credential == null) return null;
    return _requireCurrentUser().linkWithCredential(credential);
  }

  /// Same upgrade-in-place contract as [linkWithGoogle]; throws with code
  /// `email-already-in-use` on conflict.
  Future<UserCredential> linkWithEmail({
    required String email,
    required String password,
  }) {
    final credential = EmailAuthProvider.credential(email: email, password: password);
    return _requireCurrentUser().linkWithCredential(credential);
  }

  /// Abandons the anonymous session and signs into the pre-existing
  /// account instead — the manual-merge path after a link conflict
  /// (Section 3a). The caller is responsible for migrating the abandoned
  /// session's local data afterward.
  Future<void> signInWithGoogleDirectly() async {
    final credential = await _getGoogleCredential();
    if (credential == null) return;
    await _firebaseAuth.signInWithCredential(credential);
  }

  Future<void> signInWithEmailDirectly({
    required String email,
    required String password,
  }) => signInWithEmail(email: email, password: password);

  Future<void> sendPasswordResetEmail(String email) =>
      _firebaseAuth.sendPasswordResetEmail(email: email);

  Future<AuthCredential?> _getGoogleCredential() async {
    await _googleSignIn.initialize();
    final GoogleSignInAccount account;
    try {
      account = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
    final idToken = account.authentication.idToken;
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  User _requireCurrentUser() {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw StateError('No current user to link from.');
    return user;
  }

  Future<void> signOut() async {
    // Best-effort: some devices/emulators have no Credential Manager
    // provider configured, which makes Google's own sign-out throw.
    // That must never block the actual Firebase sign-out below.
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _firebaseAuth.signOut();
  }
}
