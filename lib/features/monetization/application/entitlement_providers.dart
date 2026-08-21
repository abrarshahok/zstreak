import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/revenue_cat_entitlement_repository.dart';
import '../data/revenue_cat_service.dart';
import '../domain/entitlement_repository.dart';

final revenueCatServiceProvider = Provider<RevenueCatService>(
  (ref) => RevenueCatService(),
);

final entitlementRepositoryProvider = Provider<EntitlementRepository>(
  (ref) =>
      RevenueCatEntitlementRepository(ref.watch(revenueCatServiceProvider)),
);

/// Dev-only toggle: simulates Pro (`true`) or Free (`false`) at runtime.
/// Only active in debug builds (`kDebugMode`). Ignored in release.
/// Defaults to `true` so debug builds start as Pro.
final devProOverrideProvider = StateProvider<bool>((ref) => false);

/// Whether the current user has an active premium entitlement.
///
/// Watches [authStateProvider] so it automatically re-evaluates whenever
/// the user signs in, signs out, or links an account — ensuring the paywall
/// gate is always in sync with the current Firebase uid that RevenueCat is
/// logged in as.
///
/// After a purchase or restore, call [ref.invalidate(hasActiveEntitlementProvider)]
/// to force an immediate re-check without waiting for the next auth change.
final hasActiveEntitlementProvider = FutureProvider<bool>((ref) async {
  // Re-run this provider whenever auth state changes.
  ref.watch(authStateProvider);

  // ── Dev override (debug builds only) ────────────────────────────────────
  // In debug mode: check RevenueCat first (so real test purchases work),
  // then OR with the manual toggle (so you can simulate Pro without a purchase).
  if (kDebugMode) {
    final manualOverride = ref.watch(devProOverrideProvider);
    if (manualOverride) return true; // toggle is ON → always Pro
    // Toggle is OFF → still check RevenueCat so real purchases are honoured.
    return ref.read(entitlementRepositoryProvider).hasActiveEntitlement();
  }

  // ── Normal RevenueCat check ──────────────────────────────────────────────
  return ref.read(entitlementRepositoryProvider).hasActiveEntitlement();
});
