import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/color_hex.dart';

// ─── Section Card ─────────────────────────────────────────────────────────────

class EditSectionCard extends StatelessWidget {
  const EditSectionCard({
    super.key,
    required this.child,
    this.label,
    this.hasError = false,
  });
  final Widget child;
  final String? label;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surface : AppColors.surfaceLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final borderColor = hasError
        ? AppColors.danger
        : (isDark ? AppColors.border : AppColors.borderLight);
    final labelColor = hasError ? AppColors.danger : textMuted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: hasError
            ? AppColors.danger.withValues(alpha: 0.04)
            : surfaceColor,
        border: Border.all(color: borderColor, width: hasError ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: TextStyle(
                color: labelColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

// ─── Day Chip ─────────────────────────────────────────────────────────────────

class EditDayChip extends StatelessWidget {
  const EditDayChip({
    super.key,
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.background : AppColors.backgroundLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final borderInactive = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);
    // Compute a readable foreground for the selected accent background.
    final selectedFg = contrastForeground(accentColor);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected ? accentColor : bgColor,
          border: Border.all(color: selected ? accentColor : borderInactive),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? selectedFg : textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ─── Counter Button ───────────────────────────────────────────────────────────

class EditCounterButton extends StatelessWidget {
  const EditCounterButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.background : AppColors.backgroundLight;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final borderDisabled = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onPressed != null ? accent.withValues(alpha: 0.15) : bgColor,
          border: Border.all(
            color: onPressed != null
                ? accent.withValues(alpha: 0.4)
                : borderDisabled,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onPressed != null ? accent : textMuted,
        ),
      ),
    );
  }
}

// ─── Save Button ──────────────────────────────────────────────────────────────
//
// Docked to the bottom of the screen via `Scaffold.bottomNavigationBar`
// (same anchoring as the sign-in screen's Google button) rather than a
// floating action button — a centered FAB over scrolling content read as
// an afterthought bolted on top of the form, not the form's own primary
// action.
//
// Deliberately its own shape rather than matching every other rectangle
// on the screen: a full pill (radius = half its own height) marks this
// specific control as *the* primary action, and a press-scale animation
// gives it the tactile, "physical" feel a screen's one confirming tap
// deserves — flat color fields elsewhere on this screen don't need that,
// but the button you commit the whole form with does. A leading icon
// (check for editing, plus for creating) reinforces what the tap does
// without leaning on the button's label text alone.
class EditSaveButton extends StatefulWidget {
  const EditSaveButton({
    super.key,
    required this.isEditing,
    required this.isSaving,
    required this.accentColor,
    required this.onPressed,
  });
  final bool isEditing;
  final bool isSaving;
  final Color accentColor;
  final VoidCallback onPressed;

  @override
  State<EditSaveButton> createState() => _EditSaveButtonState();
}

class _EditSaveButtonState extends State<EditSaveButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final fg = contrastForeground(widget.accentColor);
    final disabled = widget.isSaving;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: disabled ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            color: disabled
                ? widget.accentColor.withValues(alpha: 0.6)
                : widget.accentColor,
          ),
          child: Center(
            child: widget.isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: fg,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isEditing
                            ? Icons.check_rounded
                            : Icons.add_rounded,
                        color: fg,
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.isEditing ? 'Save changes' : 'Create habit',
                        style: GoogleFonts.outfit(
                          color: fg,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
