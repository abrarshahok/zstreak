import 'package:firebase_auth/firebase_auth.dart';
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

/// Keeps RevenueCat's own identity (`Purchases.logIn`/`logOut`) in sync
/// with the current Firebase uid — the single place that call happens now.
///
/// This used to be a `ref.listen(authStateProvider, ...)` side effect in
/// `app.dart` that fired `service.logIn(uid)` *without awaiting it*, while
/// [hasActiveEntitlementProvider] separately watched the same
/// [authStateProvider] and immediately queried RevenueCat's customer info.
/// Both reactions fired off the same auth-state change with no ordering
/// guarantee between them — if the entitlement check (or a purchase, or a
/// restore) ran before `logIn(uid)` actually reached RevenueCat's servers,
/// it read/wrote against the *previous* identity (e.g. the anonymous guest
/// ID, or a different account entirely) instead of the one just signed
/// into. A purchase attributed to the wrong RevenueCat customer during
/// that window is about as broken as a paywall gets.
///
/// Making this its own [FutureProvider] and having every other
/// RevenueCat-touching provider/call `await
/// ref.watch(revenueCatIdentitySyncProvider.future)` first turns that
/// implicit race into an explicit dependency Riverpod actually orders
/// correctly. It also subsumes what `app.dart`'s old `_initRevenueCat`
/// special-cased by hand for cold start (reading the already-resolved
/// initial uid, since a plain `ref.listen` never fires for a value that
/// resolved before it was registered) — a `FutureProvider` evaluates
/// against whatever its dependencies' *current* value already is the
/// first time anything watches it, so that case just falls out for free
/// here instead of needing a separate manual check.
final revenueCatIdentitySyncProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(revenueCatServiceProvider);
  // Awaits the stream's actual next/current value instead of reading
  // authStateProvider's AsyncValue synchronously (`.valueOrNull`) — while
  // it's still resolving (AsyncLoading, e.g. right after a cold start),
  // that read returns null and this would call service.logOut() as if
  // signed out, when a real user is just about to resolve a moment
  // later. Firebase's authStateChanges() always emits an initial value
  // promptly, so this doesn't add a meaningful wait.
  User? user;
  try {
    user = await ref.watch(authStateProvider.future);
  } catch (_) {
    user = null; // Auth stream itself errored — treat as signed out.
  }
  if (user != null) {
    await service.logIn(user.uid);
  } else {
    await service.logOut();
  }
});

/// Dev-only toggle: simulates Pro (`true`) or Free (`false`) at runtime.
/// Only active in debug builds (`kDebugMode`). Ignored in release.
/// Defaults to `true` so debug builds start as Pro.
final devProOverrideProvider = StateProvider<bool>((ref) => true);

/// Whether the current user has an active premium entitlement.
///
/// Depends on [revenueCatIdentitySyncProvider] (not [authStateProvider]
/// directly — see that provider's doc comment for why) so it automatically
/// re-evaluates whenever the user signs in, signs out, or links an
/// account, *after* RevenueCat's own identity has actually caught up —
/// ensuring the paywall gate is always checked against the right customer.
///
/// After a purchase or restore, call [ref.invalidate(hasActiveEntitlementProvider)]
/// to force an immediate re-check without waiting for the next auth change.
final hasActiveEntitlementProvider = FutureProvider<bool>((ref) async {
  // ── Dev override (debug builds only) ────────────────────────────────────
  // Checked first and short-circuits before touching RevenueCat at all —
  // no reason to wait on identity sync just to return a hardcoded `true`.
  if (kDebugMode) {
    final manualOverride = ref.watch(devProOverrideProvider);
    if (manualOverride) return true; // toggle is ON → always Pro
  }

  // Toggle is OFF (or this is a release build) → wait for RevenueCat's
  // identity to be caught up, then check for real so genuine purchases
  // are honoured.
  await ref.watch(revenueCatIdentitySyncProvider.future);
  return ref.read(entitlementRepositoryProvider).hasActiveEntitlement();
});
