import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../core/utils/auth_error_messages.dart';
import '../application/account_status_providers.dart';
import '../application/auth_providers.dart';
import '../domain/account_status.dart';

/// Wraps the normal signed-in app and intercepts it whenever the
/// account's status isn't active.
///
/// [AccountStatus.inactive] means the user deactivated their own account
/// from Settings — nothing was deleted, but Firestore's security rules
/// now deny every read/write under it, so this must run *before*
/// [SignedInHomeGate] ever mounts a habit list that would otherwise just
/// surface as permission-denied errors. The screen shown here carries its
/// own "Reactivate account" button — no separate auto-popup dialog on top
/// of it. An imperative `showDialog` always lands on top of whatever the
/// *app's* single Navigator currently shows, not necessarily on top of
/// *this* widget specifically, since this gate stays mounted underneath
/// any route pushed on top of Home (e.g. Settings) even while hidden. That
/// mismatch is exactly what caused the dialog to pop up mid-deactivation,
/// on top of Settings, before sign-out had even completed — and again on
/// top of this very screen at the next login. The screen alone avoids both.
///
/// [AccountStatus.restrict] is reserved for a future admin/moderation
/// action — nothing in the app sets it today. It deliberately has no
/// self-service reactivate button, since only an admin put it there.
class AccountStatusGate extends ConsumerWidget {
  const AccountStatusGate({super.key, required this.child});

  final Widget child;

  Future<void> _reactivate(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    try {
      await ref.read(accountStatusRepositoryProvider).reactivate(uid);
    } catch (e, st) {
      // The reactivate button is never shown once the window has passed,
      // so reaching this should be unreachable in practice — but
      // Firestore's own rule rejects the write past the deadline too
      // (the real enforcement), and a rejected write must not surface as
      // an unhandled exception if it's ever somehow triggered. Still
      // worth recording and telling the user, rather than a tap that
      // silently does nothing.
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordError(
          e,
          st,
          reason: 'account reactivate',
        );
      } else {
        debugPrint('[AccountStatusGate] reactivate failed: $e');
      }
      if (context.mounted) {
        AppSnackBar.show(
          context,
          authErrorMessage(e),
          type: SnackBarType.error,
        );
      }
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (e, st) {
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordError(e, st, reason: 'sign out');
      } else {
        debugPrint('[AccountStatusGate] signOut failed: $e');
      }
      if (context.mounted) {
        AppSnackBar.show(
          context,
          authErrorMessage(e),
          type: SnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(accountStatusProvider);

    // Defaulting valueOrNull to "active" while this is still loading —
    // e.g. accountStatusProvider re-subscribing fresh after the app was
    // killed and reopened — briefly let SignedInHomeGate mount and try
    // habit reads Firestore's rules would deny for a genuinely
    // deactivated/restricted account, exactly the race this gate's own
    // doc comment says it exists to prevent. Same fix shape as
    // profileHydratingProvider elsewhere in the auth flow: hold here
    // until the real status is known instead of assuming the safe case.
    if (statusAsync.isLoading && !statusAsync.hasValue) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        backgroundColor: isDark
            ? AppColors.background
            : AppColors.backgroundLight,
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: isDark ? AppColors.accent : AppColors.accentTextOnLight,
          ),
        ),
      );
    }

    final record =
        statusAsync.valueOrNull ??
        const AccountStatusRecord(status: AccountStatus.active);

    if (record.status == AccountStatus.active) return child;

    // Locked out of self-service reactivation for one of two reasons:
    // an admin restricted the account (AccountStatus.restrict), or the
    // 30-day window since deactivation has simply passed. Both get the
    // same "contact support" screen — Firestore's own security rules
    // reject a client's attempt to write status back to 'active' in
    // either case, so there's no working "Reactivate" button to offer.
    if (record.status == AccountStatus.restrict ||
        record.isPastReactivationWindow) {
      final isExpiredWindow = record.status == AccountStatus.inactive;
      return _AccountLockedScreen(
        icon: '🔒',
        title: isExpiredWindow
            ? 'Your reactivation window has passed'
            : 'Your account is restricted',
        body: isExpiredWindow
            ? "It's been more than 30 days since you deactivated. Your data hasn't been deleted, but this account can no longer be reactivated on your own - contact support if you'd like to discuss recovering it."
            : 'Your account has been restricted and is temporarily inaccessible. Contact support if you think this is a mistake.',
        primaryLabel: 'Contact support',
        onPrimary: () => launchUrl(Uri.parse('mailto:zstreak26@gmail.com')),
        onSignOut: () => _signOut(context, ref),
      );
    }

    // AccountStatus.inactive, still within the 30-day window.
    return _AccountLockedScreen(
      icon: '💤',
      title: 'Your account is deactivated',
      body: record.daysUntilDeadline != null
          ? "Nothing was deleted. Reactivate to pick up right where you left off - you have ${record.daysUntilDeadline} day${record.daysUntilDeadline == 1 ? '' : 's'} left in your reactivation window."
          : 'Nothing was deleted. Reactivate to pick up right where you left off.',
      primaryLabel: 'Reactivate account',
      onPrimary: () => _reactivate(context, ref),
      onSignOut: () => _signOut(context, ref),
    );
  }
}

class _AccountLockedScreen extends StatelessWidget {
  const _AccountLockedScreen({
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onSignOut,
  });

  final String icon;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.background : AppColors.backgroundLight;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;
    final buttonFg = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: surface,
                    border: Border.all(color: border, width: 1),
                  ),
                  child: Center(
                    child: Text(icon, style: const TextStyle(fontSize: 39)),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textMuted, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onPrimary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: buttonFg,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      primaryLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onSignOut,
                  child: Text('Sign out', style: TextStyle(color: textMuted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
