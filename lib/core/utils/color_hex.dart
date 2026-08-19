import 'package:flutter/material.dart';

/// Habits store their grid color as a hex string (spec Section 5's
/// `color_hex` field) — these keep the conversion in one place.
String colorToHex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

Color colorFromHex(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  return Color(int.parse('FF$cleaned', radix: 16));
}

/// Returns [Colors.white] or [Colors.black] — whichever has better contrast
/// against [background]. Uses the WCAG relative luminance threshold (0.179)
/// so text/icons placed on top of a habit color are always legible.
Color contrastForeground(Color background) =>
    background.computeLuminance() > 0.179 ? Colors.black : Colors.white;

/// Returns [color] itself when it has sufficient contrast against [surface],
/// otherwise returns [fallback] (typically textMuted / textPrimary).
/// Threshold 0.7 luminance catches near-white colors on light surfaces.
Color readableAccent(Color color, {required Color fallback}) =>
    color.computeLuminance() > 0.7 ? fallback : color;
