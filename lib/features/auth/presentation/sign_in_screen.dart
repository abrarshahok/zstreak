import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/copy/app_copy.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../core/utils/auth_error_messages.dart';
import '../../analytics/analytics_service.dart';
import '../../monetization/presentation/paywall_screen.dart';
import '../../onboarding/application/user_profile_provider.dart';
import '../../onboarding/presentation/user_profile_questions_screen.dart';
import '../application/auth_providers.dart';
import '../data/auth_repository.dart';

/// Sign-in screen — Google one-tap only.
///
/// [fromOnboarding] = true means the user just came through the question
/// flow — we greet them by name.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({
    super.key,
    this.fromOnboarding = false,
    this.thenPaywall = false,
  });

  final bool fromOnboarding;

  /// When `true`, navigates to [PaywallScreen] after a successful sign-in
  /// instead of popping to root. Used when the user came from the "Go Pro"
  /// guest gate.
  final bool thenPaywall;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _isBusy = false;

  void _showError(String message) {
    if (!mounted) return;
    AppSnackBar.show(context, message, type: SnackBarType.error);
  }

  Future<void> _signInWithGoogle(AuthRepository repo) async {
    setState(() => _isBusy = true);
    try {
      final credential = await repo.signInWithGoogle();
      if (credential == null) return;
      final isNewUser = credential.additionalUserInfo?.isNewUser ?? false;
      final analytics = ref.read(analyticsServiceProvider);
      await (isNewUser
          ? analytics.logSignUp('google')
          : analytics.logLogin('google'));
      if (!mounted) return;
      if (widget.thenPaywall) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PaywallScreen()),
        );
      } else if (isNewUser) {
        // New user — take them through the profile questionnaire before Home.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) =>
                const UserProfileQuestionsScreen(alreadySignedIn: true),
          ),
          (_) => false,
        );
      } else {
        // Returning user — go straight to root (AuthGate handles routing).
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e, st) {
      // authErrorMessage() collapses anything non-Firebase (e.g. a raw
      // GoogleSignInException from Credential Manager — cert/config
      // mismatches surface this way) into one generic string, so the real
      // cause needs to be logged here or it's simply gone.
      if (kDebugMode) {
        debugPrint('[Auth] Google sign-in failed: $e');
      } else {
        FirebaseCrashlytics.instance.recordError(
          e,
          st,
          reason: 'Google sign-in failed',
        );
      }
      _showError(authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(authRepositoryProvider);
    final profile = ref.watch(userProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.background : AppColors.backgroundLight;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;
    final surfaceColor = isDark ? AppColors.surface : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.border : AppColors.borderLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: textPrimary,
                ),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      // The Google button + fine print live here, pinned to the bottom of
      // the screen, rather than inside the scrollable body — previously
      // everything sat in one Center+Column, so on any screen taller than
      // the content, the whole block (headline and button together)
      // floated in the middle with large, purposeless gaps above and
      // below it. Anchoring the primary action to the bottom is the
      // standard shape for a sign-in screen and reads as "designed" even
      // when the body content above is short.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.border : AppColors.borderLight,
              ),
            ),
          ),
          child:
              Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _GoogleButton(
                        isBusy: _isBusy,
                        onPressed: () => _signInWithGoogle(repo),
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        textPrimary: textPrimary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'By continuing, you agree to our Terms and Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  )
                  .animate()
                  .fadeIn(delay: 280.ms, duration: 350.ms)
                  .slideY(begin: 0.1, end: 0),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: _GoogleOnlyView(
            profile: profile,
            accent: accent,
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textMuted: textMuted,
            isDark: isDark,
          ),
        ),
      ),
    );
  }
}

// ── Google-only view ──────────────────────────────────────────────────────────

class _GoogleOnlyView extends StatelessWidget {
  const _GoogleOnlyView({
    required this.profile,
    required this.accent,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textMuted,
    required this.isDark,
  });

  final dynamic profile;
  final Color accent;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textMuted;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final firstName = (profile?.firstName as String?) ?? '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Hero ──────────────────────────────────────────────────────────
        _HeroSection(
          firstName: firstName,
          accent: accent,
          textPrimary: textPrimary,
          textMuted: textMuted,
        ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1),

        const SizedBox(height: 40),

        // ── What signing in gets you — fills the space the old
        // centered layout left blank, and gives the bottom-pinned
        // button somewhere to point back to. ────────────────────────
        _BenefitRow(
          emoji: '🔥',
          text: 'Streaks that carry over to every device',
          accent: accent,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPrimary: textPrimary,
        ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.05),
        const SizedBox(height: 14),
        _BenefitRow(
          emoji: '📊',
          text: 'A full history of your consistency, never lost',
          accent: accent,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPrimary: textPrimary,
        ).animate().fadeIn(delay: 160.ms).slideX(begin: -0.05),
        const SizedBox(height: 14),
        _BenefitRow(
          emoji: '☁️',
          text: 'Backed up automatically - nothing to lose',
          accent: accent,
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textPrimary: textPrimary,
        ).animate().fadeIn(delay: 220.ms).slideX(begin: -0.05),
      ],
    );
  }
}

// ─── Benefit row ──────────────────────────────────────────────────────────────

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.emoji,
    required this.text,
    required this.accent,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
  });

  final String emoji;
  final String text;
  final Color accent;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: accent.withValues(alpha: 0.10),
            border: Border.all(color: accent.withValues(alpha: 0.20), width: 1),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 17)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Hero Section ─────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    this.firstName = '',
  });
  final String firstName;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    final hasName = firstName.isNotEmpty;
    final headline = hasName
        ? 'Welcome,\n$firstName! 👋'
        : 'Sign in to\nZStreak. ⚡';
    final sub = hasName
        ? "Let's get your streaks synced."
        : 'Your streaks, synced everywhere.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wordmark pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: accent.withValues(alpha: 0.10),
            border: Border.all(color: accent.withValues(alpha: 0.25), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚡', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text(
                'ZSTREAK',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          headline,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: textPrimary,
            height: 1.1,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          sub,
          style: TextStyle(color: textMuted, fontSize: 14, height: 1.4),
        ),
      ],
    );
  }
}

// ─── Google Button ────────────────────────────────────────────────────────────

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({
    required this.isBusy,
    required this.onPressed,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
  });
  final bool isBusy;
  final VoidCallback onPressed;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isBusy ? null : onPressed,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: surfaceColor,
          border: Border.all(color: borderColor, width: 1),
        ),
        child: isBusy
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _GoogleGlyph(),
                  const SizedBox(width: 12),
                  Text(
                    AppCopy.continueWithGoogle,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Google Glyph ─────────────────────────────────────────────────────────────

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/google_logo.svg',
      width: 24,
      height: 24,
    );
  }
}
