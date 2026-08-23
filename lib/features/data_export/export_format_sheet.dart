import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../monetization/application/entitlement_providers.dart';
import '../monetization/presentation/paywall_navigation.dart';
import 'data_export_providers.dart';

/// The one place every "export my data" entry point (Settings, Analytics,
/// the link-account screen, the guest-expiry interstitial) routes through
/// — lets the user pick CSV (raw, spreadsheet-friendly, free for everyone)
/// or PDF (a formatted report, a Pro feature — it's the same "deep
/// analytics" value the Analytics screen itself is gated behind) instead
/// of always getting CSV.
Future<void> showExportFormatSheet(BuildContext context, WidgetRef ref) async {
  // Checked once, up front, so the sheet can render the PDF option in its
  // final state immediately rather than flashing locked-then-unlocked.
  final isPro = await ref.read(hasActiveEntitlementProvider.future);
  if (!context.mounted) return;

  final isDark = Theme.of(context).brightness == Brightness.dark;
  final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
  final border = isDark ? AppColors.border : AppColors.borderLight;
  final textPrimary = isDark
      ? AppColors.textPrimary
      : AppColors.textPrimaryLight;
  final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
  final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(sheetContext).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: textMuted.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Export your data',
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your full habit and check-in history, either way.',
            style: TextStyle(color: textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 18),
          _ExportOption(
            icon: Icons.table_chart_outlined,
            title: 'CSV',
            subtitle: 'Raw data - every check-in as a spreadsheet row.',
            accent: accent,
            textPrimary: textPrimary,
            textMuted: textMuted,
            border: border,
            onTap: () {
              Navigator.of(sheetContext).pop();
              ref.read(dataExporterProvider).shareCsv(isPro: isPro);
            },
          ),
          const SizedBox(height: 10),
          _ExportOption(
            icon: Icons.picture_as_pdf_outlined,
            title: 'PDF',
            subtitle: isPro
                ? 'Formatted report - summary, weekly chart, and a per-habit breakdown table.'
                : 'Formatted report with charts and tables.',
            locked: !isPro,
            accent: accent,
            textPrimary: textPrimary,
            textMuted: textMuted,
            border: border,
            onTap: () {
              Navigator.of(sheetContext).pop();
              if (isPro) {
                ref.read(dataExporterProvider).sharePdf(isPro: isPro);
              } else {
                navigateToPaywall(context, ref);
              }
            },
          ),
        ],
      ),
    ),
  );
}

class _ExportOption extends StatelessWidget {
  const _ExportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    required this.border,
    required this.onTap,
    this.locked = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;
  final Color border;
  final VoidCallback onTap;

  /// True for a Pro-only format the current user hasn't unlocked — still
  /// tappable (routes to the paywall instead of exporting), just badged
  /// so the lock isn't a surprise.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (locked) ...[
                        const SizedBox(width: 6),
                        const _ProBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: textMuted),
          ],
        ),
      ),
    );
  }
}

/// Same gold bolt-and-"PRO" pill used app-wide (e.g. Home's quick-add row)
/// to mark a locked Pro feature — kept local since the original is a
/// private widget in `home_screen.dart`.
class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.premiumGold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.premiumGold.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 10, color: AppColors.premiumGold),
          const SizedBox(width: 2),
          Text(
            'PRO',
            style: TextStyle(
              color: AppColors.premiumGold,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
