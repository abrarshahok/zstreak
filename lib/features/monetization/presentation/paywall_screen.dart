import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/copy/app_copy.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../account_linking/presentation/link_account_screen.dart';
import '../../analytics/analytics_service.dart';
import '../../auth/application/auth_providers.dart';
import '../application/entitlement_providers.dart';

// ─── Offerings provider ───────────────────────────────────────────────────────

final _offeringsProvider = FutureProvider<List<Package>>((ref) async {
  final offerings = await ref.read(revenueCatServiceProvider).getOfferings();
  return offerings.current?.availablePackages ?? [];
});

// ─── Paywall screen ───────────────────────────────────────────────────────────

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _isBusy = false;
  int _selectedIndex = 0;

  Future<void> _purchase(Package package) async {
    setState(() => _isBusy = true);
    try {
      await ref.read(revenueCatServiceProvider).purchasePackage(package);
      await ref
          .read(analyticsServiceProvider)
          .logPurchaseCompleted(package.storeProduct.identifier);
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
      await ref.read(revenueCatServiceProvider).restorePurchases();
      if (!mounted) return;
      ref.invalidate(hasActiveEntitlementProvider);
      final isPremium = await ref.read(hasActiveEntitlementProvider.future);
      if (!mounted) return;
      _showMessage(isPremium ? 'Restored ✅' : 'No previous purchase found.');
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

  void _showMessage(String message) {
    if (!mounted) return;
    AppSnackBar.show(context, message, type: SnackBarType.error);
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Go Pro',
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
        loading: () => Center(
          child: CircularProgressIndicator(color: accent, strokeWidth: 2),
        ),
        error: (_, _) => _ErrorBody(
          accent: accent,
          textMuted: textMuted,
          onRetry: () => ref.invalidate(_offeringsProvider),
        ),
        data: (packages) => Stack(
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

                // Testimonials
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: _Testimonials(
                      isDark: isDark,
                      accent: accent,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                    ).animate().fadeIn(delay: 250.ms),
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

                // Package selector
                if (packages.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: _PackageSelector(
                        packages: packages,
                        selectedIndex: _selectedIndex,
                        onSelect: (i) => setState(() => _selectedIndex = i),
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

                // Bottom padding for sticky CTA
                const SliverToBoxAdapter(child: SizedBox(height: 130)),
              ],
            ),

            // ── Sticky CTA ─────────────────────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _StickyCta(
                packages: packages,
                selectedIndex: _selectedIndex,
                isBusy: _isBusy,
                isDark: isDark,
                accent: accent,
                textPrimary: textPrimary,
                textMuted: textMuted,
                bgColor: bgColor,
                borderColor: borderColor,
                onPurchase: packages.isEmpty
                    ? null
                    : () => _purchase(packages[_selectedIndex]),
                onRestore: _restore,
              ),
            ),
          ],
        ),
      ),
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
          AppCopy.paywallHeadline,
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
          'Everything you need to build habits that actually stick — unlimited, synced, and always with you.',
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
    final rows = <(String, Object, Object)>[
      ('Habits', '3 max', 'Unlimited'),
      ('Home screen widget', false, true),
      ('Cloud sync', false, true),
      ('Analytics & insights', false, true),
      ('Priority support', false, true),
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

// ─── Testimonials ─────────────────────────────────────────────────────────────

class _Testimonials extends StatelessWidget {
  const _Testimonials({
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
    const reviews = [
      (
        'Zara K.',
        'ZK',
        Color(0xFF9EE000),
        '"Finally a habit app that doesn\'t feel like homework. The streak widget on my home screen is everything."',
      ),
      (
        'Marcus T.',
        'MT',
        Color(0xFF00C2FF),
        '"Upgraded after 3 days. The unlimited habits alone are worth it — I track 9 things now."',
      ),
      (
        'Priya S.',
        'PS',
        Color(0xFFE040FB),
        '"Cloud sync saved me when I switched phones. Didn\'t lose a single day of my 60-day streak."',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What people are saying',
          style: TextStyle(
            color: textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: reviews.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final r = reviews[i];
              return Container(
                width: 238,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: surfaceColor,
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: r.$3.withValues(alpha: 0.18),
                          ),
                          child: Center(
                            child: Text(
                              r.$2,
                              style: TextStyle(
                                color: r.$3,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.$1,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Text('⭐⭐⭐⭐⭐', style: TextStyle(fontSize: 8)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        r.$4,
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 11,
                          height: 1.45,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
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
          final isFirst = i == 0;
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
                                  pkg.storeProduct.title,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (isFirst) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    color: accent,
                                  ),
                                  child: Text(
                                    'BEST VALUE',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.black
                                          : Colors.white,
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
                                color: const Color(
                                  0xFF22C55E,
                                ).withValues(alpha: 0.15),
                                border: Border.all(
                                  color: const Color(
                                    0xFF22C55E,
                                  ).withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '🎁 $trialLabel',
                                style: const TextStyle(
                                  color: Color(0xFF22C55E),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ] else if (pkg
                              .storeProduct
                              .description
                              .isNotEmpty) ...[
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
                          Text(
                            'FREE',
                            style: TextStyle(
                              color: const Color(0xFF22C55E),
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          )
                        else
                          Text(
                            pkg.storeProduct.priceString,
                            style: TextStyle(
                              color: isSelected ? accent : textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        if (trialLabel != null)
                          Text(
                            'then ${pkg.storeProduct.priceString}',
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
              '🎁 $trialDuration free, then ${selectedPkg!.storeProduct.priceString}',
              style: const TextStyle(
                color: Color(0xFF22C55E),
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
                          : 'Get Pro · ${selectedPkg.storeProduct.priceString}',
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
