import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/genz_background.dart';
import '../../guest/presentation/guest_home_gate.dart';
import '../../onboarding/application/onboarding_providers.dart';
import '../../onboarding/presentation/onboarding_screen.dart';
import '../../onboarding/presentation/post_auth_onboarding_flow.dart';
import '../application/auth_providers.dart';
import 'signed_in_home_gate.dart';

/// Root router: branches purely on [AuthStage] so no other widget needs
/// to know how that stage was derived (spec Section 2 / Stage 1). Once
/// authenticated, [onboardingCompleteProvider] gates one more time —
/// spec Section 3's notification-permission and first-habit steps must
/// run once before Home, for both guest and signed-in starts.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => GenZBackground(
        accentColor: AppColors.accent,
        child: const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.accent,
              ),
            ),
          ),
        ),
      ),
      error: (_, _) => const OnboardingScreen(),
      data: (_) {
        final stage = ref.watch(authStageProvider);
        if (stage == AuthStage.noAuthYet) return const OnboardingScreen();
        if (!ref.watch(onboardingCompleteProvider)) {
          return const PostAuthOnboardingFlow();
        }
        return switch (stage) {
          AuthStage.noAuthYet => const OnboardingScreen(),
          AuthStage.guest => const GuestHomeGate(),
          AuthStage.signedIn => const SignedInHomeGate(),
        };
      },
    );
  }
}
