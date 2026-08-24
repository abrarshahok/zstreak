import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
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
    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
    await Purchases.configure(
      PurchasesConfiguration(RevenueCatConfig.androidApiKey)
        // Trusted Entitlements (informational mode): asks the SDK to flag
        // whether an entitlement it reports was actually verified against
        // RevenueCat's servers, rather than only ever trusting whatever
        // the on-device cache says. Doesn't block or change anything on
        // its own — grants still go through as normal on a verification
        // failure — hasActiveEntitlement() below just also gets a signal
        // it can act on. Only produces a real (non-"not requested")
        // result once Informational Mode is also turned on in the
        // RevenueCat dashboard (Project Settings -> Entitlement
        // Verification); until then this is a safe no-op.
        // See https://rev.cat/trusted-entitlements.
        ..entitlementVerificationMode = EntitlementVerificationMode.informational,
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
      final active = info.entitlements.active;
      if (kDebugMode) {
        debugPrint('[RC] active entitlements: ${active.keys.toList()}');
        debugPrint(
          '[RC] checking for: ${RevenueCatConfig.premiumEntitlementId}',
        );
      }
      final hasEntitlement = active.containsKey(
        RevenueCatConfig.premiumEntitlementId,
      );
      // Trusted Entitlements (see initialize()) flagged this specific
      // entitlement as not matching what RevenueCat's servers say it
      // should be — grant still goes through (informational mode never
      // blocks), but a tampered/rooted-device response wouldn't produce
      // this any other way, so it's worth a signal.
      if (hasEntitlement && !kDebugMode) {
        final verification =
            active[RevenueCatConfig.premiumEntitlementId]?.verification;
        if (verification == VerificationResult.failed) {
          FirebaseCrashlytics.instance.recordError(
            StateError(
              'RC entitlement "${RevenueCatConfig.premiumEntitlementId}" '
              'present but failed Trusted Entitlements verification',
            ),
            StackTrace.current,
            reason: 'RC entitlement verification failed',
          );
        }
      }
      // The customer has *some* active entitlement, but not the one this
      // build expects — almost always an identifier typo/rename on the
      // RevenueCat dashboard (space, casing, etc.) rather than a real "no
      // purchase" case. That would otherwise look identical to a free user
      // and go unnoticed for every customer, so flag it loudly instead of
      // just returning false.
      if (!hasEntitlement && active.isNotEmpty && !kDebugMode) {
        FirebaseCrashlytics.instance.recordError(
          StateError(
            'Active RC entitlement(s) ${active.keys.toList()} present but '
            'none match expected id '
            '"${RevenueCatConfig.premiumEntitlementId}"',
          ),
          StackTrace.current,
          reason: 'RC entitlement id mismatch',
        );
      }
      return hasEntitlement;
    } catch (e, st) {
      // Fail closed — never grant premium features on a lookup error.
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordError(
          e,
          st,
          reason: 'RC entitlement check',
        );
      } else {
        debugPrint('[RC] hasActiveEntitlement error: $e');
      }
      return false;
    }
  }
}
