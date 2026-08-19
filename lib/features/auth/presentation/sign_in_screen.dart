import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/copy/app_copy.dart';
import '../../../core/theme/app_theme.dart';
import '../../analytics/analytics_service.dart';
import '../../onboarding/application/user_profile_provider.dart';
import '../application/auth_providers.dart';
import '../data/auth_repository.dart';

/// Minimal flat Sign-in / Sign-up screen.
/// No gradients, no glow, no glass — solid surfaces with 1px borders.
/// Fully theme-aware (dark + light).
///
/// [fromOnboarding] = true means the user just came through the question
/// flow — we greet them by name and default to registration mode.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.fromOnboarding = false});

  final bool fromOnboarding;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isBusy = false;
  late bool _isRegistering;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _isRegistering = widget.fromOnboarding;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isBusy = true);
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      _showError(_messageFor(e));
    } catch (_) {
      _showError(AppCopy.errorGeneric);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
        return AppCopy.errorNetwork;
      case 'invalid-credential':
      case 'invalid-email':
      case 'wrong-password':
      case 'user-not-found':
        return AppCopy.errorInvalidCredentials;
      default:
        return AppCopy.errorGeneric;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      _showError(_messageFor(e));
    } catch (_) {
      _showError(AppCopy.errorGeneric);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _submitEmail(AuthRepository repo) async {
    await _run(() async {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final analytics = ref.read(analyticsServiceProvider);
      if (_isRegistering) {
        await repo.registerWithEmail(email: email, password: password);
        await analytics.logSignUp('email');
      } else {
        await repo.signInWithEmail(email: email, password: password);
        await analytics.logLogin('email');
      }
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Enter your email above first, then tap this again.');
      return;
    }
    await _run(() async {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    });
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
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: isDark ? AppColors.border : AppColors.borderLight,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Hero section ──────────────────────────────────────────
                _HeroSection(
                  isRegistering: _isRegistering,
                  firstName: profile.firstName,
                  accent: accent,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1),

                const SizedBox(height: 36),

                // ── Google button ─────────────────────────────────────────
                _GoogleButton(
                  isBusy: _isBusy,
                  onPressed: () => _signInWithGoogle(repo),
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

                const SizedBox(height: 20),

                // ── Divider ───────────────────────────────────────────────
                _OrDivider(
                  textMuted: textMuted,
                ).animate().fadeIn(delay: 150.ms),

                const SizedBox(height: 20),

                // ── Email field ───────────────────────────────────────────
                _FlatTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  accent: accent,
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                const SizedBox(height: 12),

                // ── Password field ────────────────────────────────────────
                _FlatTextField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  accent: accent,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: textMuted,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),

                // ── Forgot password ───────────────────────────────────────
                if (!_isRegistering)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isBusy ? null : _forgotPassword,
                      child: Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 280.ms)
                else
                  const SizedBox(height: 12),

                const SizedBox(height: 8),

                // ── Primary CTA — flat, no glow ───────────────────────────
                _FlatButton(
                  label: _isRegistering
                      ? AppCopy.createAccount
                      : AppCopy.signIn,
                  isBusy: _isBusy,
                  accent: accent,
                  isDark: isDark,
                  onPressed: () => _submitEmail(repo),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

                const SizedBox(height: 20),

                // ── Toggle register / sign-in ─────────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: _isBusy
                        ? null
                        : () =>
                              setState(() => _isRegistering = !_isRegistering),
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(fontSize: 13, color: textMuted),
                        children: [
                          TextSpan(
                            text: _isRegistering
                                ? 'Already have an account? '
                                : 'New here? ',
                          ),
                          TextSpan(
                            text: _isRegistering ? 'Sign in' : 'Create account',
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 350.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Hero Section ─────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.isRegistering,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    this.firstName = '',
  });
  final bool isRegistering;
  final String firstName;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    final hasName = firstName.isNotEmpty;

    final registerHeadline = hasName
        ? "Nice to meet\nyou, $firstName! 👋"
        : 'Create your\naccount.';
    final signInHeadline = hasName
        ? 'Welcome\nback, $firstName! 👋'
        : 'Welcome\nback. 👋';

    final registerSub = hasName
        ? "Let's get your account set up so your streaks are safe."
        : 'Your streaks, synced everywhere you sign in.';
    const signInSub = 'Pick up your streak right where you left it.';

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
          isRegistering ? registerHeadline : signInHeadline,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: textPrimary,
            height: 1.1,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isRegistering ? registerSub : signInSub,
          style: TextStyle(color: textMuted, fontSize: 14, height: 1.4),
        ),
      ],
    );
  }
}

// ─── Google Button ────────────────────────────────────────────────────────────

/// Flat Google sign-in button — solid surface, 1px border, no box shadow.
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
        child: Row(
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

// ─── Or Divider ───────────────────────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.textMuted});
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: textMuted.withValues(alpha: 0.2))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or',
            style: TextStyle(
              color: textMuted.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: textMuted.withValues(alpha: 0.2))),
      ],
    );
  }
}

// ─── Flat Text Field ──────────────────────────────────────────────────────────

/// Replaces the old _GlassTextField — solid surface, 1px border, no opacity hack.
class _FlatTextField extends StatelessWidget {
  const _FlatTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.surfaceColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textMuted,
    required this.accent,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color surfaceColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textMuted;
  final Color accent;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: surfaceColor,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: textMuted.withValues(alpha: 0.8),
            fontSize: 13,
          ),
          prefixIcon: Icon(icon, color: textMuted, size: 20),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: accent.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

// ─── Flat Button ──────────────────────────────────────────────────────────────

/// Replaces the old _GlowButton — solid fill, no box shadow.
class _FlatButton extends StatelessWidget {
  const _FlatButton({
    required this.label,
    required this.isBusy,
    required this.accent,
    required this.isDark,
    required this.onPressed,
  });

  final String label;
  final bool isBusy;
  final Color accent;
  final bool isDark;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fgColor = isDark ? Colors.black : Colors.white;

    return GestureDetector(
      onTap: isBusy ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isBusy ? accent.withValues(alpha: 0.5) : accent,
        ),
        child: Center(
          child: isBusy
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: fgColor,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: fgColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─── Google Glyph ─────────────────────────────────────────────────────────────

/// Official Google "G" logo rendered from the brand SVG asset.
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
