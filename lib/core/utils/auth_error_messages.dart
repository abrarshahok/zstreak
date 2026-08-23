import 'package:firebase_auth/firebase_auth.dart';

import '../copy/app_copy.dart';

/// Maps any error thrown by a Firebase Auth (or Auth-adjacent) operation
/// to a plain, non-technical message safe to show a user — the one place
/// every screen that triggers an auth operation should go through,
/// instead of either always falling back to one generic string (so a
/// network failure and a disabled account read identically, even though
/// only one of them is worth retrying) or interpolating the raw
/// exception into the message (which can leak internals like
/// `DatabaseException(...)` straight into the UI).
///
/// Account-linking conflict codes ('credential-already-in-use',
/// 'email-already-in-use', 'account-exists-with-different-credential')
/// are handled here too, but callers that offer a merge-account flow
/// (see LinkAccountScreen) should check for those codes themselves
/// *before* falling through to this, since the right response there is
/// to offer the merge flow, not show an error message.
String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'network-request-failed':
        return AppCopy.errorNetwork;
      case 'too-many-requests':
        return AppCopy.errorTooManyRequests;
      case 'user-disabled':
        return AppCopy.errorAccountDisabled;
      case 'operation-not-allowed':
        return AppCopy.errorOperationNotAllowed;
      case 'invalid-credential':
      case 'invalid-verification-code':
      case 'invalid-verification-id':
        return AppCopy.errorInvalidCredential;
      case 'requires-recent-login':
        return AppCopy.errorRequiresRecentLogin;
      case 'credential-already-in-use':
      case 'email-already-in-use':
      case 'account-exists-with-different-credential':
        return AppCopy.errorAccountConflict;
      default:
        return AppCopy.errorGeneric;
    }
  }
  return AppCopy.errorGeneric;
}
