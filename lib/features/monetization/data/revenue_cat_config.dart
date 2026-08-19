/// RevenueCat dashboard identifiers (spec Section 6/2). The API key is a
/// placeholder — replace it with the real Android public SDK key from
/// the RevenueCat dashboard before shipping; nothing else in this file
/// needs to change once real Offerings/entitlements are configured
/// there under these same names.
///
/// Dashboard setup this stage cannot do from code (spec Section 3a's
/// guest/trial-abuse note): enable device-level trial tracking so a
/// reinstall can't grant a second free trial to the same physical
/// device. This is a toggle in the RevenueCat dashboard, not a Flutter
/// SDK call — budget time to enable and test it before launch.
class RevenueCatConfig {
  RevenueCatConfig._();

  static const String androidApiKey = 'REVENUECAT_ANDROID_PUBLIC_SDK_KEY';
  static const String premiumEntitlementId = 'premium';
}
