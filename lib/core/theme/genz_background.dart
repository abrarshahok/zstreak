import 'package:flutter/material.dart';

/// Minimal flat background — replaces the old animated orb/gradient painter.
/// Just a solid scaffold background color. No animations, no gradients, no GPU cost.
class GenZBackground extends StatelessWidget {
  const GenZBackground({
    super.key,
    required this.accentColor,
    required this.child,
    // Legacy params kept for call-site compatibility — ignored.
    this.orbTopRight = true,
    this.orbBottomLeft = true,
  });

  final Color accentColor;
  final Widget child;
  final bool orbTopRight;
  final bool orbBottomLeft;

  @override
  Widget build(BuildContext context) => child;
}
