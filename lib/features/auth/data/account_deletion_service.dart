import 'package:cloud_functions/cloud_functions.dart';

/// Calls the `deleteAccount` Cloud Function (spec Section 5) — server-
/// side deletion of Firestore data followed by the Auth record. Not yet
/// wired to UI; Stage 10's Settings screen calls this from its "Delete
/// Account" button.
class AccountDeletionService {
  AccountDeletionService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<void> deleteAccount() => _functions.httpsCallable('deleteAccount').call();
}
