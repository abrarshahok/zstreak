import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/copy/app_copy.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../core/widgets/flat_confirm_dialog.dart';
import '../../analytics/analytics_service.dart';
import '../../auth/application/auth_providers.dart';
import '../../data_export/data_export_providers.dart';
import '../../guest/application/guest_providers.dart';
import '../../monetization/application/entitlement_providers.dart';
import '../../monetization/presentation/paywall_screen.dart';
import '../application/account_linking_providers.dart';
import 'merge_summary_screen.dart';

/// Account linking — upgrades the current anonymous guest to a permanent
/// account via `linkWithCredential`, then migrates local Drift data to
/// Firestore. Flat design, theme-aware.
///
/// [thenPaywall] — when `true`, navigates to [PaywallScreen] after a
/// successful link instead of popping to root. Used when the user came
/// from the "Go Pro" guest gate.
class LinkAccountScreen extends ConsumerStatefulWidget {
  const LinkAccountScreen({super.key, this.thenPaywall = false});

  final bool thenPaywall;

  @override
  ConsumerState<LinkAccountScreen> createState() => _LinkAccountScreenState();
}

class _LinkAccountScreenState extends ConsumerState<LinkAccountScreen> {
  bool _isBusy = false;

  Future<void> _linkGoogle() async {
    final repo = ref.read(authRepositoryProvider);
    await _run(() async {
      try {
        final credential = await repo.linkWithGoogle();
        if (credential == null) return;
        await _finish(isMerge: false, method: 'google');
      } on FirebaseAuthException catch (e) {
        if (_isConflict(e)) {
          await _offerMerge(
            method: 'google',
            signInDirectly: repo.signInWithGoogleDirectly,
          );
        } else {
          _showError(AppCopy.errorGeneric);
        }
      }
    });
  }

  bool _isConflict(FirebaseAuthException e) =>
      e.code == 'credential-already-in-use' || e.code == 'email-already-in-use';

  Future<void> _offerMerge({
    required String method,
    required Future<void> Function() signInDirectly,
  }) async {
    final confirmed = await showFlatConfirmDialog(
      context: context,
      title: 'This account already exists',
      body:
          'Sign in instead? Your guest data on this device can be added to that account.',
      confirmLabel: 'Sign in & merge',
      isDanger: false,
    );
    if (confirmed != true) return;
    await signInDirectly();
    await _finish(isMerge: true, method: method);
  }

  Future<void> _finish({required bool isMerge, required String method}) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;

    final timing = switch (ref.read(guestWindowStageProvider)) {
      GuestWindowStage.active => 'immediate',
      GuestWindowStage.warning => 'mid_window',
      GuestWindowStage.expired => 'forced_expiry',
    };

    final isPremium = await ref.read(hasActiveEntitlementProvider.future);
    final outcome = await ref
        .read(migrationServiceProvider)
        .migrate(uid: uid, isMerge: isMerge, isPremium: isPremium);

    await ref
        .read(analyticsServiceProvider)
        .logGuestLinked(method: method, timing: timing);

    // Force Riverpod to re-read the Firebase Auth stream so AuthGate and
    // SettingsScreen immediately reflect the new signed-in (non-anonymous)
    // user without requiring a hot reload.
    ref.invalidate(authStateProvider);

    if (!mounted) return;
    if (outcome.archivedDueToLimit > 0) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MergeSummaryScreen(outcome: outcome)),
      );
    } else {
      AppSnackBar.show(
        context,
        'Synced. Your streak is safe now.',
        type: SnackBarType.success,
      );
      if (widget.thenPaywall) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PaywallScreen()),
        );
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _isBusy = true);
    try {
      await action();
    } catch (_) {
      // Without this, anything action() throws beyond the
      // FirebaseAuthException cases already handled inline (e.g. _finish's
      // migrate() failing on a flaky Firestore batch commit) went
      // completely unhandled — no snackbar, no feedback at all, even
      // though by that point linkWithGoogle() may have already succeeded
      // and left the account non-anonymous with an incomplete migration.
      _showError(AppCopy.errorGeneric);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    AppSnackBar.show(context, message, type: SnackBarType.error);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.background : AppColors.backgroundLight;
    final surfaceColor = isDark ? AppColors.surface : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.border : AppColors.borderLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;
    final buttonFg = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: textPrimary,
          ),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppCopy.linkAccount,
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: isDark ? AppColors.border : AppColors.borderLight,
          ),
        ),
      ),
      body: SafeArea(
        // Was a plain Padding+Column relying on the body's own height to
        // center things — no scroll fallback, so a small device or a
        // large system font scale would overflow instead of scrolling
        // (same pattern account_status_gate.dart's _AccountLockedScreen
        // already guards against).
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Icon — flat rounded container ─────────────────────────
                Center(
                  child:
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: surfaceColor,
                          border: Border.all(color: borderColor, width: 1),
                        ),
                        child: const Center(
                          child: Text('🔐', style: TextStyle(fontSize: 35)),
                        ),
                      ).animate().scale(
                        begin: const Offset(0.7, 0.7),
                        end: const Offset(1.0, 1.0),
                        duration: 500.ms,
                        curve: Curves.elasticOut,
                      ),
                ),
                const SizedBox(height: 24),

                // ── Headline ──────────────────────────────────────────────
                Text(
                      'Save your streak',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 25,
                        height: 1.2,
                      ),
                    )
                    .animate(delay: 80.ms)
                    .fadeIn(duration: 350.ms)
                    .slideY(begin: 0.08, end: 0),

                const SizedBox(height: 10),

                Text(
                      'Link an account so your habits sync across devices and never expire.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    )
                    .animate(delay: 140.ms)
                    .fadeIn(duration: 350.ms)
                    .slideY(begin: 0.08, end: 0),

                const SizedBox(height: 40),

                // ── Google button — flat, no glow ─────────────────────────
                _FlatButton(
                      label: AppCopy.linkWithGoogle,
                      color: accent,
                      fgColor: buttonFg,
                      isBusy: _isBusy,
                      onTap: _isBusy ? null : _linkGoogle,
                    )
                    .animate(delay: 200.ms)
                    .fadeIn(duration: 350.ms)
                    .slideY(begin: 0.08, end: 0),

                const SizedBox(height: 24),

                // ── Export data ───────────────────────────────────────────
                Center(
                  child: TextButton(
                    onPressed: _isBusy
                        ? null
                        : () => ref.read(dataExporterProvider).shareCsv(),
                    child: Text(
                      AppCopy.exportMyData,
                      style: TextStyle(color: textMuted, fontSize: 12),
                    ),
                  ),
                ).animate(delay: 320.ms).fadeIn(duration: 350.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Flat filled button ────────────────────────────────────────────────────────

class _FlatButton extends StatelessWidget {
  const _FlatButton({
    required this.label,
    required this.color,
    required this.fgColor,
    required this.isBusy,
    required this.onTap,
  });
  final String label;
  final Color color;
  final Color fgColor;
  final bool isBusy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: isBusy ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: isBusy
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: fgColor,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: fgColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
