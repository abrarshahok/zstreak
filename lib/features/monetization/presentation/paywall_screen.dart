import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/copy/app_copy.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../account_linking/presentation/link_account_screen.dart';
import '../../analytics/analytics_service.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/sign_in_screen.dart';
import '../application/entitlement_providers.dart';

// ─── Offerings provider ───────────────────────────────────────────────────────

final _offeringsProvider = FutureProvider<List<Package>>((ref) async {
  // RevenueCat can target specific offerings per logged-in customer, so
  // fetching before Purchases.logIn(uid) has caught up risks showing
  // whatever offering the *previous* identity would have seen.
  await ref.watch(revenueCatIdentitySyncProvider.future);
  final offerings = await ref.read(revenueCatServiceProvider).getOfferings();
  // offerings.current is null whenever the RevenueCat dashboard doesn't
  // have an offering explicitly marked "current" — that's a dashboard
  // config gap, not a "no products" state, so falling back to any
  // offering that actually has packages keeps the paywall usable instead
  // of silently rendering an empty, permanently-disabled "Get Pro" button.
  final offering =
      offerings.current ??
      offerings.all.values
          .where((o) => o.availablePackages.isNotEmpty)
          .firstOrNull;
  return offering?.availablePackages ?? [];
});

/// Short billing-period suffix for a price string — "$5.99/mo",
/// "$34.99/yr" — driven by RevenueCat's own [PackageType] rather than
/// array position, so it stays correct no matter what order the
/// dashboard returns monthly/annual/lifetime in. Lifetime has no
/// recurring period, so it gets no suffix here; its "one-time" wording
/// is shown separately wherever the price itself is displayed.
String pricePeriodSuffix(Package pkg) => switch (pkg.packageType) {
  PackageType.monthly => '/mo',
  PackageType.annual => '/yr',
  PackageType.weekly => '/wk',
  _ => '',
};

bool isLifetimePackage(Package pkg) => pkg.packageType == PackageType.lifetime;

/// Google Play Billing appends " (AppName)" to every product's title at
/// the API level — e.g. "ZStreak Pro (ZStreak)" — regardless of what's
/// actually typed into the product's Name field in Play Console. It's
/// meant to disambiguate purchases in system dialogs; on the app's own
/// paywall the app's own name is just redundant, so this strips it.
String cleanProductTitle(String title) =>
    title.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();

/// Plan card title driven by [PackageType] rather than whatever's
/// configured as the product's name in Play Console — every package
/// there is literally named "ZStreak Pro" (Play Billing then appends
/// " (ZStreak)" on top of that), so the three plan cards were otherwise
/// indistinguishable at a glance.
String planTitle(Package pkg) => switch (pkg.packageType) {
  PackageType.monthly => 'Monthly Pro',
  PackageType.annual => 'Yearly Pro',
  PackageType.lifetime => 'Lifetime Pro',
  PackageType.weekly => 'Weekly Pro',
  _ => cleanProductTitle(pkg.storeProduct.title),
};

// ─── Paywall screen ───────────────────────────────────────────────────────────

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _isBusy = false;
  int _selectedIndex = 0;
  bool _userSelected = false;

  /// Annual is the recommended tier by default, regardless of what order
  /// the dashboard happens to return monthly/annual/lifetime in — falls
  /// back to the first package if no annual plan is configured.
  int _defaultIndex(List<Package> packages) {
    final annualIndex = packages.indexWhere(
      (p) => p.packageType == PackageType.annual,
    );
    return annualIndex != -1 ? annualIndex : 0;
  }

  Future<void> _purchase(Package package) async {
    final isGuest =
        ref.read(authRepositoryProvider).currentUser?.isAnonymous ?? false;
    if (isGuest) {
      // Guests can browse pricing freely, but committing to a purchase
      // anonymously risks losing it on a reinstall/device switch and
      // complicates RevenueCat identity down the line — so the sign-up
      // gate fires here, at the moment of intent, rather than blocking
      // the paywall itself from even being viewed.
      await showGuestGateSheet(context);
      return;
    }
    setState(() => _isBusy = true);
    try {
      // Without this, a purchase started right after a sign-in/account
      // link — before RevenueCat's own Purchases.logIn(uid) call for the
      // new identity has actually finished — gets attributed to whatever
      // identity RevenueCat still had loaded at that moment (e.g. the
      // previous anonymous guest, or no one at all). Money charged,
      // entitlement granted to the wrong customer — about as broken as a
      // paywall gets. See revenueCatIdentitySyncProvider's doc comment.
      await ref.read(revenueCatIdentitySyncProvider.future);
      await ref.read(revenueCatServiceProvider).purchasePackage(package);
      // The purchase itself already succeeded at this point — money
      // charged, entitlement granted by RevenueCat. A failure logging it
      // to analytics is not a purchase failure and must never be
      // reported to the user as one, or block _onPurchaseSuccess below.
      try {
        await ref
            .read(analyticsServiceProvider)
            .logPurchaseCompleted(package.storeProduct.identifier);
      } catch (_) {
        // Best-effort — analytics failing here must never look like the
        // purchase itself failed.
      }
      ref.invalidate(hasActiveEntitlementProvider);
      if (!mounted) return;
      await _onPurchaseSuccess();
    } on PlatformException catch (e) {
      final isCancelled =
          PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError;
      if (!isCancelled) _showMessage(AppCopy.errorGeneric);
    } catch (_) {
      _showMessage(AppCopy.errorGeneric);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _isBusy = true);
    try {
      // Same reasoning as _purchase above — restoring against a not-yet-
      // synced identity would look up the wrong customer's purchase
      // history entirely.
      await ref.read(revenueCatIdentitySyncProvider.future);
      await ref.read(revenueCatServiceProvider).restorePurchases();
      if (!mounted) return;
      ref.invalidate(hasActiveEntitlementProvider);
      final isPremium = await ref.read(hasActiveEntitlementProvider.future);
      if (!mounted) return;
      _showMessage(
        isPremium ? 'Restored ✅' : 'No previous purchase found.',
        type: isPremium ? SnackBarType.success : SnackBarType.warning,
      );
    } catch (_) {
      _showMessage(AppCopy.errorGeneric);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _onPurchaseSuccess() async {
    final isGuest =
        ref.read(authRepositoryProvider).currentUser?.isAnonymous ?? false;
    if (!isGuest) {
      // _restore already confirms success with "Restored ✅" — purchasing
      // had no equivalent, silently popping with no feedback at all.
      AppSnackBar.show(
        context,
        "You're Pro now 🎉",
        type: SnackBarType.success,
      );
      Navigator.of(context).pop();
      return;
    }
    final shouldLink = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.surface : AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(AppCopy.paywallPostPurchaseLinkPrompt),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Link now'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    if (shouldLink == true) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LinkAccountScreen()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _showMessage(String message, {SnackBarType type = SnackBarType.error}) {
    if (!mounted) return;
    AppSnackBar.show(context, message, type: type);
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
    final surfaceColor = isDark ? AppColors.surface : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.border : AppColors.borderLight;
    final isGuest =
        ref.watch(authRepositoryProvider).currentUser?.isAnonymous ?? false;
    final isPro = ref.watch(hasActiveEntitlementProvider).valueOrNull ?? false;

    final offeringsAsync = ref.watch(_offeringsProvider);

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
          isPro ? 'Pro' : 'Go Pro',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: borderColor),
        ),
      ),
      body: offeringsAsync.when(
        loading: () => _PaywallSkeleton(isDark: isDark),
        error: (_, _) => _ErrorBody(
          accent: accent,
          textMuted: textMuted,
          onRetry: () => ref.invalidate(_offeringsProvider),
        ),
        data: (packages) {
          final effectiveIndex = _userSelected
              ? _selectedIndex
              : _defaultIndex(packages);
          return Stack(
            children: [
              // ── Scrollable content ─────────────────────────────────────────
              CustomScrollView(
                slivers: [
                  // Hero
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: _HeroSection(
                        isDark: isDark,
                        isPro: isPro,
                        accent: accent,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                      ),
                    ),
                  ),

                  // Comparison table
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                      child: _ComparisonTable(
                        isDark: isDark,
                        accent: accent,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                      ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),
                    ),
                  ),

                  // Guest warning
                  if (isGuest)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: _GuestWarning().animate().fadeIn(delay: 300.ms),
                      ),
                    ),

                  // Package selector — nothing to select once already Pro,
                  // and there's no purchase button below for it to drive.
                  if (packages.isNotEmpty && !isPro)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                        child: _PackageSelector(
                          packages: packages,
                          selectedIndex: effectiveIndex,
                          onSelect: (i) => setState(() {
                            _selectedIndex = i;
                            _userSelected = true;
                          }),
                          isDark: isDark,
                          accent: accent,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                        ).animate().fadeIn(delay: 320.ms).slideY(begin: 0.08),
                      ),
                    ),

                  // Guarantee badge
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                      child: _GuaranteeBadge(
                        textMuted: textMuted,
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                      ).animate().fadeIn(delay: 380.ms),
                    ),
                  ),

                  // Bottom padding for the sticky CTA — this used to be a
                  // flat 130, which only matched _StickyCta's actual
                  // height on a device with no bottom system inset and no
                  // trial-label row. On a 3-button-nav device, or whenever
                  // a trial is offered, the CTA is taller than that and the
                  // guarantee badge above ends up hidden behind it even
                  // after scrolling all the way down. 190 covers the CTA's
                  // tallest case (trial label + button + restore link +
                  // its own paddings) and the bottom inset is added on top
                  // since _StickyCta pads for it separately.
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 190 + MediaQuery.of(context).padding.bottom,
                    ),
                  ),
                ],
              ),

              // ── Sticky CTA ─────────────────────────────────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _StickyCta(
                  packages: packages,
                  selectedIndex: effectiveIndex,
                  isBusy: _isBusy,
                  isPro: isPro,
                  isDark: isDark,
                  accent: accent,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                  bgColor: bgColor,
                  borderColor: borderColor,
                  onPurchase: packages.isEmpty
                      ? null
                      : () => _purchase(packages[effectiveIndex]),
                  onRestore: _restore,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Loading skeleton ─────────────────────────────────────────────────────────
//
// Mirrors the real page's section order (hero, comparison table,
// testimonials, package cards, guarantee badge) as generic placeholder
// blocks — RevenueCat's offerings fetch is the only thing gating this, and
// it's usually near-instant, but a shimmer that matches the eventual
// layout avoids a jarring re-layout jump when it resolves.
class _PaywallSkeleton extends StatelessWidget {
  const _PaywallSkeleton({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      isDark: isDark,
      builder: (context, colors) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          children: [
            ShimmerCircle(size: 64, color: colors.border),
            const SizedBox(height: 20),
            ShimmerBlock(
              height: 22,
              width: double.infinity,
              color: colors.border,
            ),
            const SizedBox(height: 10),
            ShimmerBlock(height: 14, width: 220, color: colors.border),
            const SizedBox(height: 28),
            ShimmerCard(colors: colors, height: 140, child: const SizedBox()),
            const SizedBox(height: 24),
            ShimmerCard(colors: colors, height: 90, child: const SizedBox()),
            const SizedBox(height: 24),
            Row(
              children: List.generate(2, (i) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: i == 0 ? 0 : 6,
                      right: i == 1 ? 0 : 6,
                    ),
                    child: ShimmerCard(
                      colors: colors,
                      height: 110,
                      child: const SizedBox(),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            ShimmerBlock(
              height: 40,
              width: double.infinity,
              radius: 10,
              color: colors.shimmer,
            ),
          ],
        );
      },
    );
  }
}

// ─── Error body ───────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.accent,
    required this.textMuted,
    required this.onRetry,
  });
  final Color accent;
  final Color textMuted;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, color: textMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              'Could not load pricing.\nCheck your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textMuted, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ─── Hero section ─────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.isDark,
    required this.isPro,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    required this.surfaceColor,
    required this.borderColor,
  });
  final bool isDark;
  final bool isPro;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;
  final Color surfaceColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Animated fire icon
        Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: surfaceColor,
                border: Border.all(color: borderColor, width: 1),
              ),
              child: const Center(
                child: Text('🔥', style: TextStyle(fontSize: 30)),
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(0.93, 0.93),
              end: const Offset(1.07, 1.07),
              duration: 2200.ms,
              curve: Curves.easeInOut,
            ),
        const SizedBox(height: 16),
        // Headline
        Text(
          isPro ? "You're in the full grind." : AppCopy.paywallHeadline,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            height: 1.1,
          ),
        ).animate().fadeIn(delay: 60.ms).slideY(begin: 0.12),
        const SizedBox(height: 10),
        // Sub-headline
        Text(
          isPro
              ? "Everything's unlocked - unlimited, synced, and always with you."
              : 'Everything you need to build habits that actually stick - unlimited, synced, and always with you.',
          style: TextStyle(color: textMuted, fontSize: 14, height: 1.5),
        ).animate().fadeIn(delay: 100.ms),
      ],
    );
  }
}

// ─── Comparison table ─────────────────────────────────────────────────────────

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({
    required this.isDark,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    required this.surfaceColor,
    required this.borderColor,
  });
  final bool isDark;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;
  final Color surfaceColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    // (label, freeValue, proValue) — String or bool
    // "Cloud sync" used to be listed here as Pro-only, but it's actually
    // available to any signed-in (non-guest) user regardless of
    // entitlement — habitRepositoryProvider picks Firestore vs Drift
    // purely off auth state. Replaced with backfill history, which is
    // genuinely Pro-gated (see HabitDetailScreen._logPastDay).
    // "Priority support" used to be listed here too, but nothing in the
    // app actually differentiates support by entitlement — Settings'
    // "Contact support" is the same flow for every user.
    final rows = <(String, Object, Object)>[
      ('Habits', '3 max', 'Unlimited'),
      ('Home screen widget', false, true),
      ('Backfill history', 'Last 7 days', 'Unlimited'),
      ('Reminders', 'Daily', 'Smart alerts'),
      ('Analytics & insights', false, true),
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: surfaceColor,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'FEATURE',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'FREE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: accent,
                    ),
                    child: Text(
                      'PRO',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.black : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: borderColor),
          ...rows.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value;
            final isLast = i == rows.length - 1;

            Widget buildCell(Object val, {bool isPro = false}) {
              if (val is bool) {
                return Icon(
                  val ? Icons.check_rounded : Icons.close_rounded,
                  size: 16,
                  color: val ? accent : textMuted.withValues(alpha: 0.35),
                );
              }
              return Text(
                val as String,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isPro ? textPrimary : textMuted,
                  fontSize: 12,
                  fontWeight: isPro ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          row.$1,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Center(child: buildCell(row.$2)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Center(child: buildCell(row.$3, isPro: true)),
                      ),
                    ],
                  ),
                ),
                if (!isLast) Divider(height: 1, color: borderColor),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ─── Guest warning ────────────────────────────────────────────────────────────

class _GuestWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.danger.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.danger,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppCopy.paywallGuestWarning,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Package selector ─────────────────────────────────────────────────────────

class _PackageSelector extends StatelessWidget {
  const _PackageSelector({
    required this.packages,
    required this.selectedIndex,
    required this.onSelect,
    required this.isDark,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    required this.surfaceColor,
    required this.borderColor,
  });
  final List<Package> packages;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool isDark;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;
  final Color surfaceColor;
  final Color borderColor;

  /// Returns a human-readable trial label like "3-day free trial" or null.
  String? _trialLabel(Package pkg) {
    final intro = pkg.storeProduct.introductoryPrice;
    if (intro == null) return null;
    final n = intro.periodNumberOfUnits;
    final unit = intro.periodUnit; // PeriodUnit enum: day, week, month, year
    final unitStr = switch (unit) {
      PeriodUnit.day => n == 1 ? 'day' : 'days',
      PeriodUnit.week => n == 1 ? 'week' : 'weeks',
      PeriodUnit.month => n == 1 ? 'month' : 'months',
      PeriodUnit.year => n == 1 ? 'year' : 'years',
      _ => 'days',
    };
    return '$n-$unitStr free trial';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose your plan',
          style: TextStyle(
            color: textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        ...packages.asMap().entries.map((entry) {
          final i = entry.key;
          final pkg = entry.value;
          final isSelected = i == selectedIndex;
          final isBestValue = pkg.packageType == PackageType.annual;
          final isLifetime = isLifetimePackage(pkg);
          final trialLabel = _trialLabel(pkg);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isSelected
                      ? accent.withValues(alpha: 0.08)
                      : surfaceColor,
                  border: Border.all(
                    color: isSelected
                        ? accent.withValues(alpha: 0.6)
                        : borderColor,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Radio dot
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? accent : borderColor,
                          width: isSelected ? 6 : 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  planTitle(pkg),
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (isBestValue || isLifetime) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    color: isLifetime
                                        ? AppColors.premiumGold
                                        : accent,
                                  ),
                                  child: Text(
                                    isLifetime ? 'PAY ONCE' : 'BEST VALUE',
                                    style: TextStyle(
                                      color: isLifetime
                                          ? Colors.black
                                          : (isDark
                                                ? Colors.black
                                                : Colors.white),
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          // Free trial badge
                          if (trialLabel != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                color: AppColors.success.withValues(
                                  alpha: 0.15,
                                ),
                                border: Border.all(
                                  color: AppColors.success.withValues(
                                    alpha: 0.4,
                                  ),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '🎁 $trialLabel',
                                style: const TextStyle(
                                  color: AppColors.success,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ] else if (!isLifetime &&
                              pkg.storeProduct.description.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                pkg.storeProduct.description,
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Price column — show "FREE" then price/period when trial
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (trialLabel != null)
                          const Text(
                            'FREE',
                            style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          )
                        else
                          Text.rich(
                            TextSpan(
                              text: pkg.storeProduct.priceString,
                              style: TextStyle(
                                color: isSelected ? accent : textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                              children: [
                                TextSpan(
                                  text: pricePeriodSuffix(pkg),
                                  style: TextStyle(
                                    color: textMuted,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (isLifetime)
                          Text(
                            'one-time',
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (trialLabel != null)
                          Text(
                            'then ${pkg.storeProduct.priceString}${pricePeriodSuffix(pkg)}',
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ─── Guarantee badge ──────────────────────────────────────────────────────────

class _GuaranteeBadge extends StatelessWidget {
  const _GuaranteeBadge({
    required this.textMuted,
    required this.surfaceColor,
    required this.borderColor,
  });
  final Color textMuted;
  final Color surfaceColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: surfaceColor,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🛡️', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(
            'Cancel anytime · Managed by Google Play',
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

// ─── Sticky CTA ───────────────────────────────────────────────────────────────

class _StickyCta extends StatelessWidget {
  const _StickyCta({
    required this.packages,
    required this.selectedIndex,
    required this.isBusy,
    required this.isPro,
    required this.isDark,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    required this.bgColor,
    required this.borderColor,
    required this.onPurchase,
    required this.onRestore,
  });

  final List<Package> packages;
  final int selectedIndex;
  final bool isBusy;
  final bool isPro;
  final bool isDark;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback? onPurchase;
  final VoidCallback onRestore;

  /// Returns trial duration string like "3 days" or null if no trial.
  String? _trialLabel(Package? pkg) {
    final intro = pkg?.storeProduct.introductoryPrice;
    if (intro == null) return null;
    final n = intro.periodNumberOfUnits;
    final unit = intro.periodUnit;
    final unitStr = switch (unit) {
      PeriodUnit.day => n == 1 ? 'day' : 'days',
      PeriodUnit.week => n == 1 ? 'week' : 'weeks',
      PeriodUnit.month => n == 1 ? 'month' : 'months',
      PeriodUnit.year => n == 1 ? 'year' : 'years',
      _ => 'days',
    };
    return '$n $unitStr';
  }

  @override
  Widget build(BuildContext context) {
    final buttonFg = isDark ? Colors.black : Colors.white;
    final selectedPkg = packages.isNotEmpty ? packages[selectedIndex] : null;
    final trialDuration = _trialLabel(selectedPkg);
    final hasTrial = trialDuration != null;

    if (isPro) {
      // Already subscribed — the comparison table above is still worth
      // showing (e.g. to see what's unlocked), but a "Get Pro" button that
      // charges an already-paying customer again has no legitimate use.
      return Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(top: BorderSide(color: borderColor, width: 1)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppColors.premiumGold.withValues(alpha: 0.10),
                border: Border.all(
                  color: AppColors.premiumGold.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.premiumGold.withValues(alpha: 0.18),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: AppColors.premiumGold,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "You're Pro",
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Thanks for supporting ZStreak',
                          style: TextStyle(color: textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PillLinkButton(
                    icon: Icons.settings_outlined,
                    label: 'Manage subscription',
                    textPrimary: textPrimary,
                    borderColor: borderColor,
                    onTap: () => launchUrl(
                      Uri.parse(
                        'https://play.google.com/store/account/subscriptions'
                        '?package=com.zstreak.app',
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PillLinkButton(
                    icon: Icons.restore_rounded,
                    label: AppCopy.paywallRestorePurchases,
                    textPrimary: textPrimary,
                    borderColor: borderColor,
                    onTap: isBusy ? null : onRestore,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Trial sub-label above button
          if (hasTrial) ...[
            Text(
              '🎁 $trialDuration free, then ${selectedPkg!.storeProduct.priceString}${pricePeriodSuffix(selectedPkg)}',
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Main purchase button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isBusy ? null : onPurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: buttonFg,
                disabledBackgroundColor: accent.withValues(alpha: 0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: isBusy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: buttonFg,
                      ),
                    )
                  : Text(
                      hasTrial
                          ? 'Try free for $trialDuration'
                          : selectedPkg == null
                          ? 'Get Pro'
                          : isLifetimePackage(selectedPkg)
                          ? 'Get Pro · ${selectedPkg.storeProduct.priceString} one-time'
                          : 'Get Pro · ${selectedPkg.storeProduct.priceString}${pricePeriodSuffix(selectedPkg)}',
                      style: TextStyle(
                        color: buttonFg,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          // Restore link
          GestureDetector(
            onTap: isBusy ? null : onRestore,
            child: Text(
              AppCopy.paywallRestorePurchases,
              style: TextStyle(
                color: textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pill link button (already-Pro secondary actions) ────────────────────────

class _PillLinkButton extends StatelessWidget {
  const _PillLinkButton({
    required this.icon,
    required this.label,
    required this.textPrimary,
    required this.borderColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color textPrimary;
  final Color borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: textPrimary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Guest sign-up gate (shown when a guest tries to buy) ────────────────────
//
// Moved here from paywall_navigation.dart — that helper used to show this
// before a guest could even open the paywall at all, blocking them from
// browsing pricing. Now it only fires at the moment a guest actually taps
// "buy", from _PaywallScreenState._purchase.

Future<void> showGuestGateSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _GuestGateSheet(parentContext: context),
  );
}

class _GuestGateSheet extends ConsumerWidget {
  const _GuestGateSheet({required this.parentContext});

  /// We keep a reference to the screen context so we can push routes on the
  /// main navigator after the sheet is dismissed.
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.surface : AppColors.surfaceLight;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final borderColor = isDark ? AppColors.border : AppColors.borderLight;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: const Center(
              child: Text('🔥', style: TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(height: 16),

          // Headline
          Text(
            'Create an account to go Pro',
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Sub-copy
          Text(
            'A free account keeps your streak safe and\nlets you unlock Pro features.',
            style: TextStyle(color: textMuted, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // Primary CTA — Sign up
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // close sheet
                // Replaces the guest PaywallScreen itself rather than
                // pushing on top of it — otherwise LinkAccountScreen's own
                // pushReplacement (back to a *new* PaywallScreen once
                // signed up) leaves this original one stranded underneath,
                // and back would land on a stale second paywall.
                Navigator.of(parentContext).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const LinkAccountScreen(thenPaywall: true),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: isDark ? Colors.black : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Sign up - it\'s free',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Secondary CTA — Sign in
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop(); // close sheet
              // Same reasoning as the sign-up button above.
              Navigator.of(parentContext).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const SignInScreen(
                    fromOnboarding: false,
                    thenPaywall: true,
                  ),
                ),
              );
            },
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Already have an account? ',
                    style: TextStyle(color: textMuted, fontSize: 13),
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
        ],
      ),
    );
  }
}
