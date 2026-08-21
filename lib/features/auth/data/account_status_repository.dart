import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/account_status.dart';

const Duration _reactivationWindow = Duration(days: 30);

/// Reads and writes the `status` field on a user's own `/users/{uid}` doc.
///
/// This is intentionally a plain field update, not a Cloud Function call —
/// unlike account deletion (which needs a server-side recursive delete to
/// survive a dropped connection mid-operation), deactivating is just
/// setting one field. There's nothing to roll back if it's interrupted.
class AccountStatusRepository {
  AccountStatusRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection('users').doc(uid);

  Stream<AccountStatusRecord> watchStatus(String uid) {
    return _doc(uid).snapshots().map(_toRecord);
  }

  Future<AccountStatusRecord> getStatus(String uid) async {
    return _toRecord(await _doc(uid).get());
  }

  AccountStatusRecord _toRecord(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    if (data == null) return const AccountStatusRecord(status: AccountStatus.active);
    return AccountStatusRecord(
      status: AccountStatus.fromDbValue(data['status'] as String?),
      deactivatedAt: (data['deactivatedAt'] as Timestamp?)?.toDate(),
      reactivationDeadline: (data['reactivationDeadline'] as Timestamp?)?.toDate(),
    );
  }

  /// Deactivates the account — spec: no data is deleted, only hidden
  /// behind Firestore's own security rules until reactivated.
  Future<void> deactivate(String uid) async {
    final now = DateTime.now();
    await _doc(uid).set({
      'status': AccountStatus.inactive.toDbValue(),
      'deactivatedAt': Timestamp.fromDate(now),
      'reactivationDeadline': Timestamp.fromDate(now.add(_reactivationWindow)),
    }, SetOptions(merge: true));
  }

  Future<void> reactivate(String uid) async {
    await _doc(uid).set({
      'status': AccountStatus.active.toDbValue(),
      'deactivatedAt': null,
      'reactivationDeadline': null,
    }, SetOptions(merge: true));
  }
}
