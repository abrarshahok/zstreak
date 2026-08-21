import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../notifications/application/notification_providers.dart';

import 'package:app_settings/app_settings.dart';

import '../../../core/copy/app_copy.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../core/theme/theme_mode_providers.dart';
import '../../../core/widgets/flat_confirm_dialog.dart';
import '../../../dev/seed_demo_data.dart';
import '../../account_linking/presentation/link_account_screen.dart';
import '../../auth/application/account_status_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/auth_gate.dart';
import '../../data_export/data_export_providers.dart';
import '../../guest/application/guest_providers.dart';
import '../../habits/application/habit_providers.dart';
import '../../monetization/application/entitlement_providers.dart';
import '../../monetization/presentation/paywall_navigation.dart';
import '../../onboarding/application/user_profile_provider.dart';

/// Settings screen — Gen-Z redesign with GenZBackground, glassmorphic
/// section cards, and theme-aware colors.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final isGuest = user?.isAnonymous ?? true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;

    final bgColor = isDark ? AppColors.background : AppColors.backgroundLight;

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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
        children:
            [
                  // ── Profile ───────────────────────────────────────────────────
                  _SectionLabel('Profile', accent: accent),
                  _ProfileCard(
                    isDark: isDark,
                    accent: accent,
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                  ),

                  // ── Appearance ────────────────────────────────────────────────
                  _SectionLabel('Appearance', accent: accent),
                  _SettingsCard(
                    isDark: isDark,
                    children: [
                      _ThemeModeTile(
                        isDark: isDark,
                        accent: accent,
                        textPrimary: textPrimary,
                      ),
                    ],
                  ),

                  // ── Notifications ─────────────────────────────────────────────
                  _SectionLabel('Notifications', accent: accent),
                  _NotificationPermissionTile(
                    isDark: isDark,
                    accent: accent,
                    textPrimary: textPrimary,
                    textMuted: textMuted,
                  ),

                  // ── Data ──────────────────────────────────────────────────────
                  _SectionLabel('Data', accent: accent),
                  _SettingsCard(
                    isDark: isDark,
                    children: [
                      _SettingsTile(
                        icon: Icons.ios_share_rounded,
                        label: AppCopy.exportMyData,
                        subtitle: 'Free for everyone, always',
                        accent: accent,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        onTap: () => ref.read(dataExporterProvider).shareCsv(),
                      ),
                      if (isGuest) ...[
                        _Divider(isDark: isDark),
                        _SettingsTile(
                          icon: Icons.delete_sweep_outlined,
                          label: 'Clear my data',
                          accent: AppColors.danger,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                          onTap: () => _confirmClearGuestData(context, ref),
                        ),
                      ],
                    ],
                  ),

                  // ── Account ───────────────────────────────────────────────────
                  _SectionLabel('Account', accent: accent),
                  _SettingsCard(
                    isDark: isDark,
                    children: [
                      if (isGuest) ...[
                        _SettingsTile(
                          icon: Icons.person_outline_rounded,
                          label: AppCopy.guestModeLabel,
                          subtitle: 'Your data lives on this device',
                          accent: accent,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                        ),
                        _Divider(isDark: isDark),
                        _SettingsTile(
                          icon: Icons.link_rounded,
                          label: AppCopy.linkAccount,
                          subtitle: 'Sync & back up your streaks',
                          accent: accent,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LinkAccountScreen(),
                            ),
                          ),
                        ),
                        _Divider(isDark: isDark),
                        _SettingsTile(
                          icon: Icons.logout_rounded,
                          label: 'Log out',
                          subtitle: 'Return to the start screen',
                          accent: AppColors.danger,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                          onTap: () => _confirmGuestLogOut(context, ref),
                        ),
                      ] else ...[
                        _SettingsTile(
                          icon: Icons.person_outline_rounded,
                          label: user?.email ?? 'Signed in with Google',
                          accent: accent,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                        ),
                        _Divider(isDark: isDark),
                        _SettingsTile(
                          icon: Icons.logout_rounded,
                          label: 'Log out',
                          accent: accent,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                          onTap: () => _logOut(context, ref),
                        ),
                        _Divider(isDark: isDark),
                        _SettingsTile(
                          icon: Icons.pause_circle_outline,
                          label: 'Deactivate account',
                          subtitle: 'Data is kept, not deleted — reactivate anytime',
                          accent: AppColors.danger,
                          textPrimary: AppColors.danger,
                          textMuted: textMuted,
                          onTap: () => _confirmDeactivateAccount(context, ref),
                        ),
                      ],
                    ],
                  ),

                  // ── Premium ───────────────────────────────────────────────────
                  // Gold instead of the standard accent — this section should
                  // feel a notch more special than a plain settings row.
                  _SectionLabel('Premium', accent: AppColors.premiumGold),
                  _SettingsCard(
                    isDark: isDark,
                    children: [
                      _SettingsTile(
                        icon: Icons.bolt_rounded,
                        label: 'Unlock the full grind',
                        accent: AppColors.premiumGold,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        onTap: () => navigateToPaywall(context, ref),
                      ),
                      _Divider(isDark: isDark),
                      _SettingsTile(
                        icon: Icons.restore_rounded,
                        label: AppCopy.paywallRestorePurchases,
                        accent: AppColors.premiumGold,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        onTap: () => _restorePurchases(context, ref),
                      ),
                      _Divider(isDark: isDark),
                      _SettingsTile(
                        icon: Icons.widgets_outlined,
                        label: 'Add home screen widget',
                        accent: AppColors.premiumGold,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        onTap: () => _addWidget(context, ref),
                      ),
                    ],
                  ),

                  // ── Dev (debug builds only) ───────────────────────────────
                  if (kDebugMode && !isGuest) ...[
                    _SectionLabel('Dev', accent: accent),
                    _SettingsCard(
                      isDark: isDark,
                      children: [
                        _DevProModeTile(
                          isDark: isDark,
                          accent: accent,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                        ),
                        _Divider(isDark: isDark),
                        _SettingsTile(
                          icon: Icons.science_outlined,
                          label: 'Seed demo data',
                          accent: accent,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                          onTap: () => _seedDemoData(context, ref),
                        ),
                      ],
                    ),
                  ],

                  // ── Legal & Support ───────────────────────────────────────────
                  // Muted instead of the standard accent — low-emotional-weight
                  // rows that shouldn't compete visually with Premium/Account.
                  _SectionLabel('Legal & Support', accent: textMuted),
                  _SettingsCard(
                    isDark: isDark,
                    children: [
                      _SettingsTile(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Privacy Policy',
                        accent: textMuted,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        onTap: () => launchUrl(
                          Uri.parse('https://zstreak.web.app/privacy'),
                        ),
                      ),
                      _Divider(isDark: isDark),
                      _SettingsTile(
                        icon: Icons.gavel_rounded,
                        label: 'Terms of Service',
                        accent: textMuted,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        onTap: () => launchUrl(
                          Uri.parse('https://zstreak.web.app/terms'),
                        ),
                      ),
                      _Divider(isDark: isDark),
                      _SettingsTile(
                        icon: Icons.mail_outline_rounded,
                        label: 'Contact support',
                        accent: textMuted,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        onTap: () =>
                            launchUrl(Uri.parse('mailto:zstreak26@gmail.com')),
                      ),
                    ],
                  ),

                  // ── Version ───────────────────────────────────────────────────
                  const SizedBox(height: 8),
                  _AppVersionTile(textMuted: textMuted),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Built different. Built for your streak. ⚡',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ]
                .animate(interval: 40.ms)
                .fadeIn(duration: 300.ms)
                .slideY(
                  begin: 0.06,
                  end: 0,
                  duration: 300.ms,
                  curve: Curves.easeOut,
                ),
      ),
    );
  }

  Future<void> _logOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showFlatConfirmDialog(
      context: context,
      title: 'Log out?',
      body: 'You\'ll be signed out of your account.',
      confirmLabel: 'Log out',
      isDanger: true,
    );
    if (confirmed != true) return;
    await ref.read(authRepositoryProvider).signOut();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _confirmGuestLogOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showFlatConfirmDialog(
      context: context,
      title: 'You\'re in Guest Mode',
      body:
          'Logging out will permanently delete all your habits, streaks, and progress stored on this device.\n\nThis cannot be undone. Link an account first if you want to keep your progress.',
      confirmLabel: 'Delete & log out',
      isDanger: true,
    );
    if (confirmed != true) return;

    final deletionService = ref.read(accountDeletionServiceProvider);
    final guestRepo = ref.read(guestMetaRepositoryProvider);

    // ── Step 1: wipe all local Drift data (habits, check-ins, guest_meta) ───
    // Uses wipeAllLocalData() — full delete with no re-insert, since the
    // anonymous session is being destroyed and we don't need a fresh row.
    await guestRepo.wipeAllLocalData();

    // ── Step 2: clear profile data from SharedPreferences ────────────────────
    await ref.read(userProfileProvider.notifier).reset();

    // ── Step 3: navigate to AuthGate — tears down all Firestore listeners ────
    // Guest (anonymous) users are blocked from Firestore by security rules
    // (sign_in_provider != 'anonymous'), so there is no remote data to delete.
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );

    // ── Step 4: delete the Firebase Auth record (fire-and-forget) ────────────
    // Done AFTER navigation so no active listeners receive PERMISSION_DENIED
    // when the token is invalidated by user.delete().
    deletionService.deleteGuestAuthRecord().catchError(
      (e) => debugPrint(
        '[GuestLogOut] deleteGuestAuthRecord error (non-fatal): $e',
      ),
    );
  }

  Future<void> _seedDemoData(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    await seedDemoData(FirebaseFirestore.instance, uid);
    if (!context.mounted) return;
    AppSnackBar.show(context, 'Demo data seeded.', type: SnackBarType.success);
  }

  Future<void> _confirmClearGuestData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showFlatConfirmDialog(
      context: context,
      title: 'Clear all data?',
      body:
          'This permanently deletes all your local habits and check-ins. This can\'t be undone.',
      confirmLabel: 'Clear data',
      isDanger: true,
    );
    if (confirmed != true) return;
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid != null) {
      await ref.read(guestMetaRepositoryProvider).clearAllGuestData(uid);
    }
  }

  /// Replaces what used to be an immediate, permanent "Delete account":
  /// no Firestore data is deleted, only hidden. A `status: inactive` field
  /// gets set on the account's own doc, which Firestore's security rules
  /// now check on every habit/check-in/profile read and write — so this
  /// is a real access change, not just a client-side flag the UI happens
  /// to respect. Reactivating (from the login-time prompt) restores
  /// everything exactly as it was.
  Future<void> _confirmDeactivateAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showFlatConfirmDialog(
      context: context,
      title: 'Deactivate account?',
      body:
          "Your data stays exactly as it is — nothing is deleted. You'll be signed out, and your habits become inaccessible until you reactivate. You have 30 days to change your mind before that guarantee expires.",
      confirmLabel: 'Deactivate',
      isDanger: true,
    );
    if (confirmed != true) return;

    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;

    try {
      await ref.read(accountStatusRepositoryProvider).deactivate(uid);
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.show(
        context,
        'Could not deactivate account: $e',
        type: SnackBarType.error,
      );
      return;
    }

    // Sign out immediately — the account is now inactive, so there's
    // nothing left for this session to keep showing.
    await ref.read(authRepositoryProvider).signOut();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _restorePurchases(BuildContext context, WidgetRef ref) async {
    await ref.read(revenueCatServiceProvider).restorePurchases();
    final isPremium = await ref.read(hasActiveEntitlementProvider.future);
    if (!context.mounted) return;
    AppSnackBar.show(
      context,
      isPremium ? 'Restored.' : 'No previous purchase found.',
      type: isPremium ? SnackBarType.success : SnackBarType.warning,
    );
  }

  Future<void> _addWidget(BuildContext context, WidgetRef ref) async {
    final isPremium = await ref.read(hasActiveEntitlementProvider.future);
    if (!context.mounted) return;
    if (!isPremium) {
      await navigateToPaywall(context, ref);
      return;
    }
    await HomeWidget.requestPinWidget(
      qualifiedAndroidName: 'com.zstreak.app.HabitWidgetProvider',
    );
  }
}

// ── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {required this.accent});
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

// ── Flat card container ───────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children, required this.isDark});
  final List<Widget> children;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark ? AppColors.surface : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.border : AppColors.borderLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(children: children),
    );
  }
}

// ── Individual settings row ───────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(color: textMuted, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Thin divider between tiles ────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 66,
      endIndent: 0,
      color: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.06),
    );
  }
}

// ── Theme mode segmented control ──────────────────────────────────────────────

class _ThemeModeTile extends ConsumerWidget {
  const _ThemeModeTile({
    required this.isDark,
    required this.accent,
    required this.textPrimary,
  });

  final bool isDark;
  final Color accent;
  final Color textPrimary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.dark_mode_outlined, color: accent, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    expandedInsets: EdgeInsets.zero,
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(
                          'System',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(
                          'Light',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(
                          'Dark',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                    selected: {mode},
                    onSelectionChanged: (selection) =>
                        setThemeMode(ref, selection.first),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dev: simulate Pro entitlement ──────────────────────────────────────────────

/// A live, restart-free switch for [devProOverrideProvider] — previously
/// this could only be flipped by editing its default and doing a full
/// hot *restart* (a hot reload alone keeps the provider's already-built
/// state), which read as "Pro mode doesn't work" when it was really just
/// stale state from before the edit.
class _DevProModeTile extends ConsumerWidget {
  const _DevProModeTile({
    required this.isDark,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
  });

  final bool isDark;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOn = ref.watch(devProOverrideProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.workspace_premium_outlined,
              color: accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Simulate Pro',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  isOn
                      ? 'On — every paywall gate is unlocked'
                      : 'Off — real entitlement is checked',
                  style: TextStyle(color: textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: isOn,
            activeThumbColor: accent,
            onChanged: (v) {
              ref.read(devProOverrideProvider.notifier).state = v;
              // Force an immediate re-check instead of waiting for the next
              // auth-state change to naturally re-run the provider.
              ref.invalidate(hasActiveEntitlementProvider);
            },
          ),
        ],
      ),
    );
  }
}

// ── Notification permission tile ──────────────────────────────────────────────

class _NotificationPermissionTile extends ConsumerStatefulWidget {
  const _NotificationPermissionTile({
    required this.isDark,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
  });

  final bool isDark;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;

  @override
  ConsumerState<_NotificationPermissionTile> createState() =>
      _NotificationPermissionTileState();
}

class _NotificationPermissionTileState
    extends ConsumerState<_NotificationPermissionTile>
    with WidgetsBindingObserver {
  bool _granted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check when the user returns from system Settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  Future<void> _checkPermission() async {
    final svc = ref.read(notificationServiceProvider);
    final ok = await svc.areNotificationsEnabled();
    if (mounted) setState(() => _granted = ok);
  }

  Future<void> _handleTap() async {
    final svc = ref.read(notificationServiceProvider);
    if (_granted) {
      // Already enabled — open notification settings so user can manage
      // channels (e.g. mute streak-at-risk but keep daily reminders).
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
      return;
    }
    // Not yet granted: try the system permission dialog first.
    final result = await svc.requestNotificationPermission();
    if (mounted) setState(() => _granted = result);
    if (!result && mounted) {
      // Permanently denied — system dialog won't show again.
      // Send the user directly to the app's notification settings page.
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = widget.isDark
        ? AppColors.surface
        : AppColors.surfaceLight;
    final borderColor = widget.isDark
        ? AppColors.border
        : AppColors.borderLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: _SettingsTile(
        icon: _granted
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined,
        label: 'Notifications',
        subtitle: _granted ? 'Enabled — tap to manage' : 'Tap to enable',
        accent: _granted ? widget.accent : AppColors.danger,
        textPrimary: widget.textPrimary,
        textMuted: widget.textMuted,
        onTap: _handleTap,
      ),
    );
  }
}

// ── App version tile ──────────────────────────────────────────────────────────

class _AppVersionTile extends StatelessWidget {
  const _AppVersionTile({required this.textMuted});
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data;
        return Center(
          child: Text(
            version == null
                ? ''
                : 'v${version.version} (${version.buildNumber})',
            style: TextStyle(color: textMuted, fontSize: 11),
          ),
        );
      },
    );
  }
}

// ── Profile card ──────────────────────────────────────────────────────────────

/// Editable profile section — shows current values and opens a bottom sheet
/// to edit each field. Answers are persisted to SharedPreferences via
/// [UserProfileNotifier].
///
/// Uses [ConsumerStatefulWidget] so the age wheel picker can use a proper
/// [StatefulWidget] internally, avoiding any closure-capture ambiguity.
class _ProfileCard extends ConsumerStatefulWidget {
  const _ProfileCard({
    required this.isDark,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
  });

  final bool isDark;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;

  @override
  ConsumerState<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<_ProfileCard> {
  /// Returns the current user's uid when signed in with Google, null for guests.
  String? get _uid {
    final user = ref.read(authStateProvider).valueOrNull;
    return (user != null && user.isAnonymous == false) ? user.uid : null;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);

    final initials = profile.name.trim().isEmpty
        ? '?'
        : profile.name
              .trim()
              .split(' ')
              .map((w) => w[0])
              .take(2)
              .join()
              .toUpperCase();

    final dividerColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    final initialsFallback = Center(
      child: Text(
        initials,
        style: TextStyle(
          color: widget.accent,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
    );
    final hasPhoto = (profile.photoUrl ?? '').isNotEmpty;

    return _SettingsCard(
      isDark: widget.isDark,
      children: [
        // ── Hero header: avatar + name + edit-name tap ──────────────────────
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          onTap: () => _editTextField(
            title: 'Your name',
            icon: Icons.person_outline_rounded,
            initialValue: profile.name,
            capitalization: TextCapitalization.words,
            onSave: (v) =>
                ref.read(userProfileProvider.notifier).setName(v, uid: _uid),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Row(
              children: [
                // Avatar — Google profile photo when available, initials
                // fallback otherwise (guests, or the image failing to load).
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.accent.withValues(alpha: 0.15),
                    border: Border.all(
                      color: widget.accent.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: hasPhoto
                      ? ClipOval(
                          child: Image.network(
                            profile.photoUrl!,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                initialsFallback,
                          ),
                        )
                      : initialsFallback,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name.isEmpty ? 'Your name' : profile.name,
                        style: TextStyle(
                          color: profile.name.isEmpty
                              ? widget.textMuted
                              : widget.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _ProfileStatLine(textMuted: widget.textMuted),
                    ],
                  ),
                ),
                Icon(Icons.edit_outlined, color: widget.textMuted, size: 16),
              ],
            ),
          ),
        ),

        Divider(height: 1, indent: 16, endIndent: 16, color: dividerColor),

        // ── Age + Gender side-by-side chips ─────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              // Age chip
              Expanded(
                child: _InfoChip(
                  icon: Icons.cake_outlined,
                  label: 'Age',
                  value: profile.age.isEmpty ? 'Not set' : '${profile.age} yrs',
                  accent: widget.accent,
                  textPrimary: widget.textPrimary,
                  textMuted: widget.textMuted,
                  isDark: widget.isDark,
                  onTap: () => _editAgePicker(currentAge: profile.age),
                ),
              ),
              const SizedBox(width: 10),
              // Gender chip
              Expanded(
                child: _InfoChip(
                  icon: Icons.wc_rounded,
                  label: 'Gender',
                  value: profile.gender.isEmpty ? 'Not set' : profile.gender,
                  accent: widget.accent,
                  textPrimary: widget.textPrimary,
                  textMuted: widget.textMuted,
                  isDark: widget.isDark,
                  onTap: () => _editChoice(
                    title: 'How do you identify?',
                    choices: const [
                      'Male',
                      'Female',
                      'Non-binary',
                      'Prefer not to say',
                    ],
                    current: profile.gender,
                    onSave: (v) => ref
                        .read(userProfileProvider.notifier)
                        .setGender(v, uid: _uid),
                  ),
                ),
              ),
            ],
          ),
        ),

        Divider(height: 1, indent: 16, endIndent: 16, color: dividerColor),

        // ── Goals section ───────────────────────────────────────────────────
        InkWell(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
          onTap: () => _editMultiChoice(
            title: "What are your goals?",
            choices: const [
              'Build healthy habits',
              'Stay consistent',
              'Improve productivity',
              'Personal growth',
              'Mental wellness',
              'Physical fitness',
            ],
            current: profile.goals,
            onSave: (v) =>
                ref.read(userProfileProvider.notifier).setGoals(v, uid: _uid),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.flag_outlined, color: widget.accent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'GOALS',
                      style: TextStyle(
                        color: widget.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.edit_outlined,
                      color: widget.textMuted,
                      size: 14,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (profile.goals.isEmpty)
                  Text(
                    'Tap to set your goals',
                    style: TextStyle(
                      color: widget.textMuted,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: profile.goals.map((g) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: widget.accent.withValues(alpha: 0.12),
                          border: Border.all(
                            color: widget.accent.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          g,
                          style: TextStyle(
                            color: widget.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Text field editor ───────────────────────────────────────────────────────

  Future<void> _editTextField({
    required String title,
    required IconData icon,
    required String initialValue,
    required Future<void> Function(String) onSave,
    TextCapitalization capitalization = TextCapitalization.none,
    int maxLength = 40,
    bool isRequired = true,
  }) async {
    // Use a dedicated StatefulWidget so the TextEditingController has a proper
    // lifecycle tied to the sheet's widget tree — avoids "used after disposed"
    // errors that occur when the controller is created outside the builder and
    // disposed after showModalBottomSheet returns (e.g. on hot restart).
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) => _TextFieldSheet(
        title: title,
        icon: icon,
        initialValue: initialValue,
        capitalization: capitalization,
        maxLength: maxLength,
        isRequired: isRequired,
        onSave: onSave,
      ),
    );
  }

  // ── Age wheel picker ────────────────────────────────────────────────────────

  Future<void> _editAgePicker({required String currentAge}) async {
    const minAge = 10;
    const maxAge = 80;
    final parsed = int.tryParse(currentAge);
    // Start at the current saved age, or 22 as a sensible default.
    final initialAge = (parsed != null && parsed >= minAge && parsed <= maxAge)
        ? parsed
        : 22;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) => _AgePickerSheet(
        initialAge: initialAge,
        minAge: minAge,
        maxAge: maxAge,
        onSave: (age) async {
          await ref
              .read(userProfileProvider.notifier)
              .setAge(age.toString(), uid: _uid);
        },
      ),
    );
  }

  // ── Multi-select choice picker ───────────────────────────────────────────────

  Future<void> _editMultiChoice({
    required String title,
    required List<String> choices,
    required List<String> current,
    required Future<void> Function(List<String>) onSave,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
        final textPrimary = isDark
            ? AppColors.textPrimary
            : AppColors.textPrimaryLight;
        final textMuted = isDark
            ? AppColors.textMuted
            : AppColors.textMutedLight;
        final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;
        final handleColor = isDark
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.12);
        final borderColor = isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06);
        final borderInactive = isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.07);
        final selected = List<String>.from(current);
        return StatefulBuilder(
          builder: (ctx, setState) => Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: handleColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pick as many as you like',
                  style: TextStyle(color: textMuted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ...choices.map((c) {
                  final isSelected = selected.contains(c);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (isSelected) {
                        selected.remove(c);
                      } else {
                        selected.add(c);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: isSelected
                            ? accent.withValues(alpha: 0.12)
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? accent.withValues(alpha: 0.5)
                              : borderInactive,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              c,
                              style: TextStyle(
                                color: isSelected ? textPrimary : textMuted,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Icon(
                            isSelected
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            color: isSelected
                                ? accent
                                : textMuted.withValues(alpha: 0.3),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _SaveButton(
                  onTap: () async {
                    await onSave(selected);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Single-select choice picker ──────────────────────────────────────────────

  Future<void> _editChoice({
    required String title,
    required List<String> choices,
    required String current,
    required Future<void> Function(String) onSave,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
        final textPrimary = isDark
            ? AppColors.textPrimary
            : AppColors.textPrimaryLight;
        final textMuted = isDark
            ? AppColors.textMuted
            : AppColors.textMutedLight;
        final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;
        final handleColor = isDark
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.12);
        final borderColor = isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06);
        final borderInactive = isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.07);
        String selected = current;
        return StatefulBuilder(
          builder: (ctx, setState) => Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: handleColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 16),
                ...choices.map((c) {
                  final isSelected = selected == c;
                  return GestureDetector(
                    onTap: () => setState(() => selected = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: isSelected
                            ? accent.withValues(alpha: 0.12)
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? accent.withValues(alpha: 0.5)
                              : borderInactive,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              c,
                              style: TextStyle(
                                color: isSelected ? textPrimary : textMuted,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: accent,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                _SaveButton(
                  onTap: () async {
                    if (selected.isNotEmpty) await onSave(selected);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Profile stat line ─────────────────────────────────────────────────────────
//
// Replaces the plain "Tap to edit name" hint with a real, live number —
// habit count and best-ever streak — so the profile header reflects
// actual progress instead of reading as a static form field.
class _ProfileStatLine extends ConsumerWidget {
  const _ProfileStatLine({required this.textMuted});
  final Color textMuted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(activeHabitsProvider).valueOrNull;
    if (habits == null || habits.isEmpty) {
      return Text(
        'Tap to edit name',
        style: TextStyle(
          color: textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    // Live per-habit longest streak — habit.longestStreak only refreshes
    // on a real structural list change now that activeHabitsProvider
    // suppresses check-in-only re-emissions (see its own doc comment).
    final bestStreak = habits.fold<int>(0, (best, h) {
      final live =
          ref.watch(streakDetailProvider(h)).valueOrNull?.longestStreak ??
          h.longestStreak;
      return live > best ? live : best;
    });
    final habitLabel = habits.length == 1 ? 'habit' : 'habits';
    return Text(
      '${habits.length} $habitLabel · 🔥 $bestStreak day best',
      style: TextStyle(
        color: textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

// ── Text field sheet (StatefulWidget — controller lifecycle tied to widget) ───

/// Dedicated [StatefulWidget] for the name-edit bottom sheet.
///
/// Keeping the [TextEditingController] inside the widget's [State] ensures it
/// is created when the sheet mounts and disposed when it unmounts — preventing
/// the "TextEditingController used after being disposed" error that occurs when
/// the controller is created outside [showModalBottomSheet]'s builder and
/// disposed after the future resolves (e.g. on hot restart).
class _TextFieldSheet extends StatefulWidget {
  const _TextFieldSheet({
    required this.title,
    required this.icon,
    required this.initialValue,
    required this.onSave,
    this.capitalization = TextCapitalization.none,
    this.maxLength = 40,
    this.isRequired = true,
  });

  final String title;
  final IconData icon;
  final String initialValue;
  final Future<void> Function(String) onSave;
  final TextCapitalization capitalization;
  final int maxLength;
  final bool isRequired;

  @override
  State<_TextFieldSheet> createState() => _TextFieldSheetState();
}

class _TextFieldSheetState extends State<_TextFieldSheet> {
  late final TextEditingController _ctrl;
  String? _fieldError;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final handleColor = isDark
        ? Colors.white.withValues(alpha: 0.2)
        : Colors.black.withValues(alpha: 0.12);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final fieldBg = isDark
        ? AppColors.background.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.04);
    final fieldBorder = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.07);

    return Padding(
      // Shift the sheet up when the keyboard appears.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        // Prevents RenderFlex overflow when content + keyboard exceed viewport.
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: handleColor,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 16),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: _fieldError != null
                      ? AppColors.danger.withValues(alpha: 0.04)
                      : fieldBg,
                  border: Border.all(
                    color: _fieldError != null ? AppColors.danger : fieldBorder,
                    width: _fieldError != null ? 1.5 : 1,
                  ),
                ),
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  textCapitalization: widget.capitalization,
                  maxLength: widget.maxLength,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  onChanged: (_) {
                    if (_fieldError != null) {
                      setState(() => _fieldError = null);
                    }
                  },
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      widget.icon,
                      color: _fieldError != null ? AppColors.danger : textMuted,
                      size: 20,
                    ),
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              if (_fieldError != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 13,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _fieldError!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _SaveButton(
                onTap: () async {
                  final value = _ctrl.text.trim();
                  if (widget.isRequired && value.isEmpty) {
                    setState(() => _fieldError = 'This field is required');
                    return;
                  }
                  if (value.length > widget.maxLength) {
                    setState(
                      () => _fieldError =
                          'Must be ${widget.maxLength} characters or less',
                    );
                    return;
                  }
                  // Capture navigator before the async gap to satisfy
                  // use_build_context_synchronously lint.
                  final nav = Navigator.of(context);
                  await widget.onSave(value);
                  if (mounted) nav.pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Age picker sheet (StatefulWidget so selectedAge is proper state) ──────────

class _AgePickerSheet extends StatefulWidget {
  const _AgePickerSheet({
    required this.initialAge,
    required this.minAge,
    required this.maxAge,
    required this.onSave,
  });

  final int initialAge;
  final int minAge;
  final int maxAge;
  final Future<void> Function(int age) onSave;

  @override
  State<_AgePickerSheet> createState() => _AgePickerSheetState();
}

class _AgePickerSheetState extends State<_AgePickerSheet> {
  late int _selectedAge;
  late FixedExtentScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _selectedAge = widget.initialAge;
    _scrollCtrl = FixedExtentScrollController(
      initialItem: widget.initialAge - widget.minAge,
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;
    final handleColor = isDark
        ? Colors.white.withValues(alpha: 0.2)
        : Colors.black.withValues(alpha: 0.12);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    const itemHeight = 56.0;
    const visibleItems = 5;
    const pickerHeight = itemHeight * visibleItems;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: handleColor,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'How old are you?',
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Scroll to pick your age',
            style: TextStyle(color: textMuted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          // Drum picker
          SizedBox(
            height: pickerHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Selection band
                Positioned(
                  top: (pickerHeight - itemHeight) / 2,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: itemHeight,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      border: Border.symmetric(
                        horizontal: BorderSide(
                          color: accent.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                // Wheel
                ListWheelScrollView.useDelegate(
                  controller: _scrollCtrl,
                  itemExtent: itemHeight,
                  perspective: 0.003,
                  diameterRatio: 2.2,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    setState(() => _selectedAge = widget.minAge + index);
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: widget.maxAge - widget.minAge + 1,
                    builder: (context, index) {
                      final age = widget.minAge + index;
                      final isSel = age == _selectedAge;
                      return Center(
                        child: Text(
                          '$age',
                          style: TextStyle(
                            color: isSel
                                ? accent
                                : textMuted.withValues(alpha: 0.5),
                            fontSize: isSel ? 28 : 20,
                            fontWeight: isSel
                                ? FontWeight.w800
                                : FontWeight.w400,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Top fade — use surface.withValues(alpha:0) instead of
                // Colors.transparent to avoid Flutter's "fade through black"
                // gradient interpolation bug.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: itemHeight * 1.5,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [surface, surface.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottom fade
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: itemHeight * 1.5,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [surface, surface.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SaveButton(
            onTap: () async {
              final nav = Navigator.of(context);
              await widget.onSave(_selectedAge);
              if (mounted) nav.pop();
            },
          ),
        ],
      ),
    );
  }
}

// ── Reusable save button ──────────────────────────────────────────────────────

/// Async-safe save button. Accepts a [Future<void> Function()] so errors are
/// properly caught and the button shows a loading indicator while saving.
class _SaveButton extends StatefulWidget {
  const _SaveButton({required this.onTap});
  final Future<void> Function() onTap;

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _loading = false;

  Future<void> _handleTap() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onTap();
    } catch (e) {
      debugPrint('[SaveButton] onTap error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;
    final fgColor = isDark ? Colors.black : Colors.white;
    return GestureDetector(
      onTap: _loading ? null : _handleTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: accent,
        ),
        child: Center(
          child: _loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                  ),
                )
              : Text(
                  'Save',
                  style: TextStyle(
                    color: fgColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Info chip (age / gender side-by-side) ────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Solid surface token — no semi-transparent hacks.
    final surfaceColor = isDark
        ? AppColors.surfaceElevated
        : AppColors.surfaceElevatedLight;
    final borderColor = isDark ? AppColors.border : AppColors.borderLight;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: surfaceColor,
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 12),
                const SizedBox(width: 4),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                Icon(Icons.edit_outlined, color: textMuted, size: 11),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: value == 'Not set' ? textMuted : textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                fontStyle: value == 'Not set'
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
