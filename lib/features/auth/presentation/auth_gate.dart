import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/outage/app_status.dart';
import '../../../core/outage/app_status_providers.dart';
import '../../../core/outage/service_unavailable_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/genz_background.dart';
import '../../guest/presentation/guest_home_gate.dart';
import '../../onboarding/application/onboarding_providers.dart';
import '../../onboarding/presentation/onboarding_screen.dart';
import '../../onboarding/presentation/post_auth_onboarding_flow.dart';
import '../../onboarding/presentation/user_profile_questions_screen.dart';
import '../application/auth_providers.dart';
import 'account_status_gate.dart';
import 'signed_in_home_gate.dart';

/// Root router: branches purely on [AuthStage] so no other widget needs
/// to know how that stage was derived (spec Section 2 / Stage 1). Once
/// authenticated, [onboardingCompleteProvider] gates one more time —
/// spec Section 3's notification-permission and first-habit steps must
/// run once before Home, for both guest and signed-in starts.
///
/// Outage gate: before any auth routing, checks [appHealthStateProvider].
/// If the circuit breaker has opened due to repeated critical Firebase
/// failures (while the device has internet), [ServiceUnavailableScreen]
/// is shown instead of the normal flow.
///
/// This is the single integration point — no other screen needs to know
/// about the outage system.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Outage gate ──────────────────────────────────────────────────────────
    // appHealthProvider is a synchronous NotifierProvider — no loading state.
    // It starts healthy and only transitions to backendUnavailable when the
    // circuit breaker opens after repeated critical Firebase failures.
    final healthState = ref.watch(appHealthStateProvider);

    if (healthState == AppHealthState.backendUnavailable) {
      final status = ref.watch(appHealthProvider);
      return ServiceUnavailableScreen(status: status);
    }

    // ── Normal auth routing ──────────────────────────────────────────────────
    final authState = ref.watch(authStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;

    return authState.when(
      loading: () => GenZBackground(
        accentColor: accent,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: accent,
              ),
            ),
          ),
        ),
      ),
      error: (_, _) => const OnboardingScreen(),
      data: (_) {
        final stage = ref.watch(authStageProvider);
        if (stage == AuthStage.noAuthYet) return const OnboardingScreen();

        // Signed-in users who bypassed the questionnaire (e.g. tapped "Sign in"
        // directly on the onboarding screen) must complete their profile first.
        if (stage == AuthStage.signedIn &&
            !ref.watch(profileCompleteProvider)) {
          return const UserProfileQuestionsScreen(alreadySignedIn: true);
        }

        if (!ref.watch(onboardingCompleteProvider)) {
          return const PostAuthOnboardingFlow();
        }
        return switch (stage) {
          AuthStage.noAuthYet => const OnboardingScreen(),
          AuthStage.guest => const GuestHomeGate(),
          // AccountStatusGate intercepts a deactivated/restricted account
          // before SignedInHomeGate ever mounts and tries to load habits
          // Firestore's own rules would now deny anyway.
          AuthStage.signedIn => const AccountStatusGate(child: SignedInHomeGate()),
        };
      },
    );
  }
}
