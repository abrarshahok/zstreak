/// RevenueCat dashboard identifiers.
///
/// ─── WHAT YOU MUST DO BEFORE SHIPPING ────────────────────────────────────
///
/// 1. Go to https://app.revenuecat.com → your project → Apps → Android.
/// 2. Copy the **Public SDK key** (starts with "goog_…").
/// 3. Replace the [androidApiKey] value below with that key.
///
/// 4. In the RevenueCat dashboard create an **Entitlement** named "premium"
///    (must match [premiumEntitlementId] exactly).
///
/// 5. Create at least one **Product** in Google Play Console, then attach it
///    to an **Offering** in RevenueCat. The paywall will show whatever
///    packages are in the "current" offering automatically.
///
/// 6. (Recommended) Enable device-level trial tracking in RevenueCat
///    dashboard → Project Settings → "Prevent free trial abuse" so a
///    reinstall can't grant a second free trial on the same device.
///
/// ─────────────────────────────────────────────────────────────────────────
class RevenueCatConfig {
  RevenueCatConfig._();

  /// RevenueCat Android Public SDK key.
  /// Current value: test key — swap for the production key before shipping.
  static const String androidApiKey = 'goog_RUwHehSsFrCVtXKxPdSeIpoLSAT';

  /// Must match the Entitlement identifier in your RevenueCat dashboard.
  static const String premiumEntitlementId = 'premium';
}
