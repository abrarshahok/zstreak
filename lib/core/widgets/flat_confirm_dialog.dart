import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The app's one confirmation-dialog look — flat, rounded, bordered, with
/// an accent/danger CTA — instead of every screen hand-rolling its own
/// stock [AlertDialog]. Returns `true` if confirmed, `false`/`null`
/// otherwise (dismissed, backdrop tap, etc).
Future<bool?> showFlatConfirmDialog({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
  required bool isDanger,
  String cancelLabel = 'Cancel',
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final surfaceColor = isDark ? AppColors.surface : AppColors.surfaceLight;
  final textPrimary = isDark
      ? AppColors.textPrimary
      : AppColors.textPrimaryLight;
  final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
  final borderColor = isDark ? AppColors.border : AppColors.borderLight;
  final confirmColor = isDanger
      ? AppColors.danger
      : (isDark ? AppColors.accent : AppColors.accentTextOnLight);
  final confirmFg = isDanger
      ? Colors.white
      : (isDark ? Colors.black : Colors.white);

  return showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: TextStyle(color: textMuted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(false),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Center(
                        child: Text(
                          cancelLabel,
                          style: TextStyle(
                            color: textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(true),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: confirmColor,
                      ),
                      child: Center(
                        child: Text(
                          confirmLabel,
                          style: TextStyle(
                            color: confirmFg,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
