import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../habits/presentation/home_screen.dart';
import '../../monetization/application/entitlement_providers.dart';
import '../application/guest_providers.dart';
import 'guest_banner.dart';
import 'guest_expired_interstitial.dart';
import 'guest_paying_reminder_banner.dart';

/// Owns the guest-window branching for Home (spec Section 3a): starts the
/// 24-hour clock on first entry, then decides between the normal Home
/// (with an escalating banner), the paying-guest reminder banner, or the
/// full blocking interstitial.
class GuestHomeGate extends ConsumerStatefulWidget {
  const GuestHomeGate({super.key});

  @override
  ConsumerState<GuestHomeGate> createState() => _GuestHomeGateState();
}

class _GuestHomeGateState extends ConsumerState<GuestHomeGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid != null) {
        ref.read(guestMetaRepositoryProvider).ensureStarted(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stage = ref.watch(guestWindowStageProvider);
    final isPaying =
        ref.watch(hasActiveEntitlementProvider).valueOrNull ?? false;

    if (stage == GuestWindowStage.expired && !isPaying) {
      return const GuestExpiredInterstitial();
    }

    final banner = stage == GuestWindowStage.expired
        ? const GuestPayingReminderBanner()
        : const GuestBanner();
    return HomeScreen(banner: banner);
  }
}
