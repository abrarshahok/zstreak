import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Deletes a guest (anonymous) account's data on the client side.
///
/// Signed-in accounts don't use this — Settings offers "Deactivate
/// Account" instead (see `_confirmDeactivateAccount` in settings_screen.dart),
/// which hides data via Firestore rules rather than deleting it.
class AccountDeletionService {
  AccountDeletionService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const _batchSize = 400;

  /// Deletes all **Firestore** data for an anonymous guest.
  ///
  /// Call this while the user is still signed in (auth token valid) and
  /// **before** navigating away. After this returns, call
  /// [deleteGuestAuthRecord] to remove the Firebase Auth record.
  ///
  /// Splitting into two steps avoids the race condition where [User.delete]
  /// invalidates the auth token while active Firestore listeners are still
  /// alive, causing spurious PERMISSION_DENIED errors on those streams.
  /// NOTE: Anonymous users are blocked from Firestore by security rules
  /// (`sign_in_provider != 'anonymous'`), so this method is effectively a
  /// no-op for guests. It is kept for completeness but callers should not
  /// rely on it to delete any data for anonymous users.
  Future<void> deleteGuestFirestoreData() async {
    final user = _auth.currentUser;
    if (user == null) return; // nothing to delete
    // Anonymous users are blocked by Firestore rules — no remote data exists.
    if (user.isAnonymous) return;

    final uid = user.uid;
    final habitsRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('habits');

    // Step 1: delete all check-in subcollections
    QuerySnapshot<Map<String, dynamic>> habitSnap;
    DocumentSnapshot? lastHabitDoc;
    do {
      var query = habitsRef.limit(_batchSize);
      if (lastHabitDoc != null) {
        query = query.startAfterDocument(lastHabitDoc);
      }
      habitSnap = await query.get();
      for (final habitDoc in habitSnap.docs) {
        await _deleteCollection(habitDoc.reference.collection('check_ins'));
      }
      lastHabitDoc = habitSnap.docs.isNotEmpty ? habitSnap.docs.last : null;
    } while (habitSnap.docs.length == _batchSize);

    // Step 2: delete all habit documents
    await _deleteCollection(habitsRef);

    // Step 3: delete the top-level user document
    await _firestore.collection('users').doc(uid).delete();
  }

  /// Deletes the Firebase Auth anonymous record.
  ///
  /// Call this **after** navigating away from any screen that holds active
  /// Firestore listeners. Anonymous users never need re-authentication, so
  /// this never throws `requires-recent-login`.
  Future<void> deleteGuestAuthRecord() async {
    final user = _auth.currentUser;
    if (user == null) return; // already deleted or signed out
    await user.delete();
  }

  /// Deletes all documents in [collectionRef] in batches of [_batchSize].
  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collectionRef,
  ) async {
    while (true) {
      final snap = await collectionRef.limit(_batchSize).get();
      if (snap.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snap.docs.length < _batchSize) break;
    }
  }
}
