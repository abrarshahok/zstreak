import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/outage/app_status.dart';
import '../../../core/outage/app_status_providers.dart';
import '../../../core/outage/service_unavailable_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../guest/presentation/guest_home_gate.dart';
import '../../onboarding/application/onboarding_providers.dart';
import '../../onboarding/application/user_profile_provider.dart';
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
      FlutterNativeSplash.remove();
      return ServiceUnavailableScreen(status: status);
    }

    // ── Normal auth routing ──────────────────────────────────────────────────
    final authState = ref.watch(authStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;

    return authState.when(
      // Still resolving — leave the native launch screen up (main.dart
      // called FlutterNativeSplash.preserve()) rather than removing it
      // straight to this Flutter-rendered fallback. It only ever becomes
      // visible if the splash was already dismissed some other way, or
      // on a hot restart, which doesn't re-show the native splash at all.
      loading: () => _AuthLoadingIndicator(accent: accent),
      error: (error, stackTrace) {
        // The auth-state stream itself erroring (e.g. a token refresh
        // failure) used to be discarded with no trace at all — falling
        // back to OnboardingScreen is still the only sane recovery (it
        // lets the user attempt to sign in again), but silently losing
        // the error meant this could never be diagnosed from Crashlytics.
        if (!kDebugMode) {
          FirebaseCrashlytics.instance.recordError(
            error,
            stackTrace,
            reason: 'authStateProvider stream',
          );
        } else {
          debugPrint('[AuthGate] authStateProvider error: $error\n$stackTrace');
        }
        FlutterNativeSplash.remove();
        return const OnboardingScreen();
      },
      data: (_) {
        final stage = ref.watch(authStageProvider);
        if (stage == AuthStage.noAuthYet) {
          FlutterNativeSplash.remove();
          return const OnboardingScreen();
        }

        // A just-completed sign-in's Firestore profile fetch is still in
        // flight — profileCompleteProvider would read the still-empty
        // local seed and misroute an existing account through the
        // name-entry screen for the couple of seconds this takes. See
        // profileHydratingProvider's doc comment. Splash stays up here too.
        if (stage == AuthStage.signedIn &&
            ref.watch(profileHydratingProvider)) {
          return _AuthLoadingIndicator(accent: accent);
        }

        FlutterNativeSplash.remove();

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
          AuthStage.signedIn => const AccountStatusGate(
            child: SignedInHomeGate(),
          ),
        };
      },
    );
  }
}

class _AuthLoadingIndicator extends StatelessWidget {
  const _AuthLoadingIndicator({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    // GenZBackground is a no-op passthrough (its old orb/gradient painter
    // was removed), so a transparent Scaffold here painted nothing behind
    // itself — falling through to Flutter's default black canvas instead
    // of the app's actual theme background.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.background : AppColors.backgroundLight;
    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: accent),
        ),
      ),
    );
  }
}
