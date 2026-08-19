import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/account_deletion_service.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

final accountDeletionServiceProvider = Provider<AccountDeletionService>(
  (ref) => AccountDeletionService(),
);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// The three auth states from spec Section 2 — routing branches on this,
/// not on the raw [User?] so the branch logic lives in exactly one place.
enum AuthStage { noAuthYet, guest, signedIn }

final authStageProvider = Provider<AuthStage>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return AuthStage.noAuthYet;
  return user.isAnonymous ? AuthStage.guest : AuthStage.signedIn;
});
