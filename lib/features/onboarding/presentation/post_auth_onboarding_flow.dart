import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../application/onboarding_providers.dart';
import '../application/user_profile_provider.dart';
import 'notification_permission_screen.dart';

/// Runs once, right after account creation or guest start (spec Section
/// 3, screens 3-4): notification permission prompt, then "create your
/// first habit" if the account doesn't have one yet. Renders nothing of
/// its own — it's a transient orchestrator that pushes each step and
/// waits for it to pop, then flips [onboardingCompleteProvider] so
/// [AuthGate] swaps straight to Home afterward.
class PostAuthOnboardingFlow extends ConsumerStatefulWidget {
  const PostAuthOnboardingFlow({super.key});

  @override
  ConsumerState<PostAuthOnboardingFlow> createState() =>
      _PostAuthOnboardingFlowState();
}

class _PostAuthOnboardingFlowState
    extends ConsumerState<PostAuthOnboardingFlow> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationPermissionScreen()),
    );
    if (!mounted) return;
    await markOnboardingComplete(ref);
    // Pop everything off the navigator stack so AuthGate's rebuilt widget
    // tree (GuestHomeGate / SignedInHomeGate) becomes visible immediately
    // without requiring a hot reload.
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.background : AppColors.backgroundLight;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;

    final profile = ref.watch(userProfileProvider);
    final firstName = profile.firstName;

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚡', style: TextStyle(fontSize: 47))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(0.85, 0.85),
                  end: const Offset(1.15, 1.15),
                  duration: 900.ms,
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 24),
            if (firstName.isNotEmpty) ...[
              Text(
                "You're all set, $firstName!",
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
              const SizedBox(height: 8),
              Text(
                "Let's build your first streak 🔥",
                style: TextStyle(color: textMuted, fontSize: 13),
              ).animate().fadeIn(delay: 350.ms, duration: 400.ms),
              const SizedBox(height: 24),
            ],
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: accent),
            ),
          ],
        ),
      ),
    );
  }
}
