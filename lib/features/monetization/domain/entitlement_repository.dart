/// Seam for premium-entitlement checks. Introduced in Stage 5 (the
/// guest-expiry interstitial's paying-guest exception needs it before
/// RevenueCat exists) behind a stub that always returned false; Stage 11
/// swaps in [RevenueCatEntitlementRepository] with no callers changing.
abstract class EntitlementRepository {
  Future<bool> hasActiveEntitlement();
}
