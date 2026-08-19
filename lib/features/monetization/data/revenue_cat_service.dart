import 'package:purchases_flutter/purchases_flutter.dart';

import 'revenue_cat_config.dart';

/// Thin wrapper around the RevenueCat SDK (spec Section 2/6/11).
///
/// Entitlements are linked to the Firebase user id via [logIn] — called
/// for BOTH guest (anonymous) and signed-in uids, per Section 2's note
/// that guests can purchase premium too. Because account linking (Stage
/// 6) upgrades the anonymous user in place without changing its uid, a
/// guest's purchase history carries over automatically through a normal
/// link — no RevenueCat-side merge needed for that path.
class RevenueCatService {
  Future<void> initialize() async {
    await Purchases.setLogLevel(LogLevel.warn);
    await Purchases.configure(
      PurchasesConfiguration(RevenueCatConfig.androidApiKey),
    );
  }

  Future<void> logIn(String uid) => Purchases.logIn(uid);

  /// RevenueCat does not allow logOut for anonymous users — guard against it.
  Future<void> logOut() async {
    try {
      final info = await Purchases.getCustomerInfo();
      // Only log out if the current RC user is not anonymous
      if (!info.originalAppUserId.startsWith('\$RCAnonymousID')) {
        await Purchases.logOut();
      }
    } catch (_) {
      // Swallow — not critical if RC logout fails
    }
  }

  Future<Offerings> getOfferings() => Purchases.getOfferings();

  Future<CustomerInfo> purchasePackage(Package package) async {
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return result.customerInfo;
  }

  Future<CustomerInfo> restorePurchases() => Purchases.restorePurchases();

  Future<bool> hasActiveEntitlement() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(
        RevenueCatConfig.premiumEntitlementId,
      );
    } catch (_) {
      // Fail closed — never grant premium features on a lookup error.
      return false;
    }
  }
}
