import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_providers.dart';
import '../data/account_status_repository.dart';
import '../domain/account_status.dart';
import 'auth_providers.dart';

final accountStatusRepositoryProvider = Provider<AccountStatusRepository>(
  (ref) => AccountStatusRepository(ref.watch(firestoreProvider)),
);

/// Only meaningful for signed-in (non-anonymous) users — guests have no
/// account to deactivate, so this always reports active for them.
final accountStatusProvider = StreamProvider<AccountStatusRecord>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || user.isAnonymous) {
    return Stream.value(
      const AccountStatusRecord(status: AccountStatus.active),
    );
  }
  return ref.watch(accountStatusRepositoryProvider).watchStatus(user.uid);
});
