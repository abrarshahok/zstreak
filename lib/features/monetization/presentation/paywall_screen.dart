import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/copy/app_copy.dart';
import '../../../core/theme/app_theme.dart';
import '../../account_linking/presentation/link_account_screen.dart';
import '../../analytics/analytics_service.dart';
import '../../auth/application/auth_providers.dart';
import '../application/entitlement_providers.dart';

/// Paywall screen — flat design, theme-aware.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _isBusy = false;

  Future<void> _purchase(Package package) async {
    setState(() => _isBusy = true);
    try {
      await ref.read(revenueCatServiceProvider).purchasePackage(package);
      await ref
          .read(analyticsServiceProvider)
          .logPurchaseCompleted(package.storeProduct.identifier);
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
      final isPremium = await ref.read(hasActiveEntitlementProvider.future);
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    final isGuest =
        ref.watch(authRepositoryProvider).currentUser?.isAnonymous ?? false;

    return Scaffold(
      backgroundColor: bgColor,
      body: FutureBuilder<Offerings>(
        future: ref.read(revenueCatServiceProvider).getOfferings(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: accent, strokeWidth: 2),
            );
          }
          final packages = snapshot.data!.current?.availablePackages ?? [];

          return CustomScrollView(
            slivers: [
              _PaywallHeroHeader(
                isDark: isDark,
                bgColor: bgColor,
                accent: accent,
                textPrimary: textPrimary,
                textMuted: textMuted,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 28),
                      // Feature pills grid
                      _FeatureGrid(
                        isDark: isDark,
                        accent: accent,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15),
                      const SizedBox(height: 32),
                      // Social proof
                      _SocialProofBar(
                        isDark: isDark,
                        accent: accent,
                        textPrimary: textPrimary,
                      ).animate().fadeIn(delay: 300.ms),
                      const SizedBox(height: 28),
                      if (isGuest)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: AppColors.danger.withValues(alpha: 0.08),
                              border: Border.all(
                                color: AppColors.danger.withValues(alpha: 0.3),
                              ),
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
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(delay: 350.ms),
                      // Pricing packages
                      if (packages.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'Offerings aren\'t configured yet in the RevenueCat dashboard.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textMuted),
                          ),
                        )
                      else
                        ...packages.asMap().entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child:
                                _PricingCard(
                                      package: entry.value,
                                      isBusy: _isBusy,
                                      onTap: () => _purchase(entry.value),
                                      isHighlighted: entry.key == 0,
                                      isDark: isDark,
                                      accent: accent,
                                      textPrimary: textPrimary,
                                      textMuted: textMuted,
                                    )
                                    .animate()
                                    .fadeIn(delay: (400 + entry.key * 80).ms)
                                    .slideY(begin: 0.1),
                          ),
                        ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _isBusy ? null : _restore,
                        child: Text(
                          AppCopy.paywallRestorePurchases,
                          style: TextStyle(color: textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Hero Header ─────────────────────────────────────────────────────────────

class _PaywallHeroHeader extends StatelessWidget {
  const _PaywallHeroHeader({
    required this.isDark,
    required this.bgColor,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
  });
  final bool isDark;
  final Color bgColor;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark ? AppColors.surface : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.border : AppColors.borderLight;

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: bgColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: surfaceColor,
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Icon(Icons.close_rounded, size: 18, color: textPrimary),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: bgColor,
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Crown emoji — flat container, no glow
                Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: surfaceColor,
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: const Center(
                        child: Text('👑', style: TextStyle(fontSize: 35)),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(0.95, 0.95),
                      end: const Offset(1.05, 1.05),
                      duration: 2000.ms,
                      curve: Curves.easeInOut,
                    ),
                const SizedBox(height: 12),
                Text(
                  AppCopy.paywallHeadline,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Join thousands building real habits.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Feature Grid ─────────────────────────────────────────────────────────────

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({
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
  Widget build(BuildContext context) {
    const features = [
      ('♾️', 'Unlimited habits', 'No cap on your grind'),
      ('🎨', 'All color themes', '7 neon palettes'),
      ('📱', 'Home widgets', 'Streak on your lock screen'),
      ('☁️', 'Cloud sync', 'Never lose your data'),
    ];

    final surfaceColor = isDark ? AppColors.surface : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.border : AppColors.borderLight;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: features
          .map(
            (f) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: surfaceColor,
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Row(
                children: [
                  Text(f.$1, style: const TextStyle(fontSize: 21)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          f.$2,
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          f.$3,
                          style: TextStyle(color: textMuted, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

// ─── Social Proof Bar ─────────────────────────────────────────────────────────

class _SocialProofBar extends StatelessWidget {
  const _SocialProofBar({
    required this.isDark,
    required this.accent,
    required this.textPrimary,
  });
  final bool isDark;
  final Color accent;
  final Color textPrimary;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark ? AppColors.surface : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.border : AppColors.borderLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: surfaceColor,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⭐⭐⭐⭐⭐', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 10),
          Text(
            '4.9 · Loved by 10k+ users',
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pricing Card ─────────────────────────────────────────────────────────────

class _PricingCard extends StatelessWidget {
  const _PricingCard({
    required this.package,
    required this.isBusy,
    required this.onTap,
    required this.isHighlighted,
    required this.isDark,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
  });

  final Package package;
  final bool isBusy;
  final VoidCallback onTap;
  final bool isHighlighted;
  final bool isDark;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark ? AppColors.surface : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.border : AppColors.borderLight;
    final buttonFg = isDark ? Colors.black : Colors.white;

    return GestureDetector(
      onTap: isBusy ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isHighlighted ? accent.withValues(alpha: 0.08) : surfaceColor,
          border: Border.all(
            color: isHighlighted ? accent.withValues(alpha: 0.5) : borderColor,
            width: isHighlighted ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isHighlighted)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: accent,
                      ),
                      child: Text(
                        'BEST VALUE',
                        style: TextStyle(
                          color: buttonFg,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  Text(
                    package.storeProduct.title,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    package.storeProduct.description,
                    style: TextStyle(color: textMuted, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  package.storeProduct.priceString,
                  style: TextStyle(
                    color: isHighlighted ? accent : textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                  ),
                ),
                if (isBusy)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accent,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: isHighlighted ? accent : surfaceColor,
                      border: isHighlighted
                          ? null
                          : Border.all(color: borderColor, width: 1),
                    ),
                    child: Text(
                      'Get it',
                      style: TextStyle(
                        color: isHighlighted ? buttonFg : textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
