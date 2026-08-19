import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/revenue_cat_entitlement_repository.dart';
import '../data/revenue_cat_service.dart';
import '../domain/entitlement_repository.dart';

/// Dev accounts that are always treated as Pro regardless of RevenueCat.
/// Remove or leave empty for production builds.
const _devProEmails = <String>{'abrarshahok@gmail.com'};

final revenueCatServiceProvider = Provider<RevenueCatService>(
  (ref) => RevenueCatService(),
);

final entitlementRepositoryProvider = Provider<EntitlementRepository>(
  (ref) =>
      RevenueCatEntitlementRepository(ref.watch(revenueCatServiceProvider)),
);

final hasActiveEntitlementProvider = FutureProvider<bool>((ref) async {
  // ── Dev override: specific accounts are always Pro ──────────────────────
  final user = FirebaseAuth.instance.currentUser;
  if (user != null &&
      user.email != null &&
      _devProEmails.contains(user.email!.toLowerCase())) {
    return true;
  }

  // ── Normal RevenueCat check ──────────────────────────────────────────────
  return ref.watch(entitlementRepositoryProvider).hasActiveEntitlement();
});
