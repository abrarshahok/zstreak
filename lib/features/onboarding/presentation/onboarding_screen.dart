import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/sign_in_screen.dart';
import 'user_profile_questions_screen.dart';

/// Full-bleed "Get Started" hero splash — the very first thing a new user
/// sees. Single screen, no slides.
///
/// Flow:
///   "Let's go ⚡" → UserProfileQuestionsScreen → auto guest sign-in → Home
///   "Already have an account? Sign in" → SignInScreen (for returning users)
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.background : AppColors.backgroundLight;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final borderColor = isDark ? AppColors.border : AppColors.borderLight;
    final surfaceColor = isDark ? AppColors.surface : AppColors.surfaceLight;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Wordmark ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: accent.withValues(alpha: 0.10),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('⚡', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 5),
                        Text(
                          'ZSTREAK',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),

            // ── Hero content ──────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),

                      // Flat emoji container — no glow, no gradient
                      Center(
                        child: _FlatEmojiHero(
                          accent: accent,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Headline
                      Text(
                            'Your habits.\nYour streak.\nYour rules.',
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                  height: 1.1,
                                  letterSpacing: -1.2,
                                ),
                          )
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 500.ms)
                          .slideY(begin: 0.15),

                      const SizedBox(height: 16),

                      // Sub-copy
                      Text(
                            'Build consistency that actually lasts. '
                            'Track habits, watch your streaks grow, '
                            'and level up every single day.',
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 14,
                              height: 1.55,
                              fontWeight: FontWeight.w400,
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 350.ms, duration: 500.ms)
                          .slideY(begin: 0.1),

                      const SizedBox(height: 40),

                      // Social proof pill — flat, no box shadow
                      _SocialProofPill(
                        accent: accent,
                        textMuted: textMuted,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                      ).animate().fadeIn(delay: 450.ms, duration: 400.ms),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // ── Bottom CTAs ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Primary CTA — flat button, no glow
                  _FlatButton(
                        label: "Let's go ⚡",
                        accent: accent,
                        isDark: isDark,
                        onPressed: () => Navigator.of(context).push(
                          PageRouteBuilder(
                            pageBuilder: (_, a, b) =>
                                const UserProfileQuestionsScreen(),
                            transitionsBuilder: (_, anim, _, child) =>
                                FadeTransition(
                                  opacity: anim,
                                  child: SlideTransition(
                                    position:
                                        Tween<Offset>(
                                          begin: const Offset(0, 0.06),
                                          end: Offset.zero,
                                        ).animate(
                                          CurvedAnimation(
                                            parent: anim,
                                            curve: Curves.easeOut,
                                          ),
                                        ),
                                    child: child,
                                  ),
                                ),
                            transitionDuration: const Duration(
                              milliseconds: 400,
                            ),
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 550.ms, duration: 400.ms)
                      .slideY(begin: 0.2),

                  const SizedBox(height: 18),

                  // Secondary CTA — returning users
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SignInScreen()),
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Already have an account? ',
                              style: TextStyle(
                                color: textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            TextSpan(
                              text: 'Sign in',
                              style: TextStyle(
                                color: accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 650.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Flat Emoji Hero ──────────────────────────────────────────────────────────

/// Replaces the old _FloatingEmoji (radial gradient + box shadow glow).
/// Simple flat rounded-rect container with a 1px border — no glow, no gradient.
class _FlatEmojiHero extends StatelessWidget {
  const _FlatEmojiHero({
    required this.accent,
    required this.surfaceColor,
    required this.borderColor,
  });
  final Color accent;
  final Color surfaceColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            color: surfaceColor,
            border: Border.all(color: borderColor, width: 1),
          ),
          child: const Center(
            child: Text('🔥', style: TextStyle(fontSize: 56)),
          ),
        )
        .animate()
        .scale(
          begin: const Offset(0.7, 0.7),
          end: const Offset(1.0, 1.0),
          duration: 600.ms,
          curve: Curves.easeOutBack,
        )
        .fadeIn(duration: 400.ms);
  }
}

// ─── Social Proof Pill ────────────────────────────────────────────────────────

/// Flat pill — no box shadow, solid border.
class _SocialProofPill extends StatelessWidget {
  const _SocialProofPill({
    required this.accent,
    required this.textMuted,
    required this.surfaceColor,
    required this.borderColor,
  });
  final Color accent;
  final Color textMuted;
  final Color surfaceColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: surfaceColor,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar stack
          SizedBox(
            width: 64,
            height: 24,
            child: Stack(
              children: [
                for (var i = 0; i < 3; i++)
                  Positioned(
                    left: i * 18.0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: [
                          accent,
                          const Color(0xFFB14EFF),
                          const Color(0xFFFF6B00),
                        ][i].withValues(alpha: 0.85),
                        border: Border.all(color: surfaceColor, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          ['😎', '🔥', '⚡'][i],
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Join thousands building streaks',
            style: TextStyle(
              color: textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Flat Button ──────────────────────────────────────────────────────────────

/// Replaces the old _GlowButton — solid fill, no box shadow.
class _FlatButton extends StatelessWidget {
  const _FlatButton({
    required this.label,
    required this.accent,
    required this.isDark,
    required this.onPressed,
  });
  final String label;
  final Color accent;
  final bool isDark;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Foreground: black on light accent (light mode), white on dark accent (dark mode)
    final fgColor = isDark ? Colors.black : Colors.white;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: accent,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: fgColor,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
