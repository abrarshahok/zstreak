import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Centralized snackbar factory matching ZStreak's flat design system.
///
/// All snackbars are:
///   - Floating, with a 12 px border-radius
///   - Theme-aware (dark / light surface colors)
///   - Outfit font, consistent weight
///   - Optional leading icon with semantic color tinting
///   - No elevation / shadow — flat like the rest of the UI
///
/// Usage:
/// ```dart
/// AppSnackBar.show(context, 'Saved!');
/// AppSnackBar.show(context, 'Something went wrong.', type: SnackBarType.error);
/// AppSnackBar.show(context, 'Synced ✓', type: SnackBarType.success);
/// ```
enum SnackBarType { info, success, error, warning }

class AppSnackBar {
  AppSnackBar._();

  static void show(
    BuildContext context,
    String message, {
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (bgColor, iconColor, icon) = _resolve(type, isDark);

    final textColor = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: EdgeInsets.zero,
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: iconColor.withValues(alpha: isDark ? 0.25 : 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Leading icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                const SizedBox(width: 12),
                // Message
                Expanded(
                  child: Text(
                    message,
                    style: GoogleFonts.outfit(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
                // Optional action
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onAction,
                    child: Text(
                      actionLabel,
                      style: GoogleFonts.outfit(
                        color: iconColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
  }

  /// Resolves (background, icon accent, icon) for each type × theme.
  static (Color, Color, IconData) _resolve(SnackBarType type, bool isDark) {
    final surface = isDark ? AppColors.surfaceElevated : AppColors.surfaceLight;

    switch (type) {
      case SnackBarType.info:
        final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;
        return (surface, accent, Icons.info_outline_rounded);

      case SnackBarType.success:
        const green = Color(0xFF4CAF50);
        return (
          isDark ? const Color(0xFF1A2A1A) : const Color(0xFFF0FAF0),
          green,
          Icons.check_circle_outline_rounded,
        );

      case SnackBarType.error:
        return (
          isDark ? const Color(0xFF2A1A1A) : const Color(0xFFFFF0F0),
          AppColors.danger,
          Icons.error_outline_rounded,
        );

      case SnackBarType.warning:
        const amber = Color(0xFFFFB300);
        return (
          isDark ? const Color(0xFF2A2210) : const Color(0xFFFFFBF0),
          amber,
          Icons.warning_amber_rounded,
        );
    }
  }
}
