import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Drives the pulsing shimmer color shared by every full-content loading
/// skeleton in the app (Home's habit-list skeleton was the original).
/// Callers draw their own placeholder shapes with [ShimmerBlock] /
/// [ShimmerCircle]; this widget only owns the animation and the
/// base/highlight/border color trio for the current theme, so every
/// skeleton across the app pulses in sync using identical tokens.
class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({super.key, required this.isDark, required this.builder});

  final bool isDark;
  final Widget Function(BuildContext context, ShimmerColors colors) builder;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class ShimmerColors {
  const ShimmerColors({required this.shimmer, required this.border});

  /// The pulsing card/background fill — lerps between the theme's surface
  /// and surfaceElevated tokens.
  final Color shimmer;

  /// Static color for inner placeholder shapes (text lines, avatars).
  final Color border;
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _shimmer = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        final base = widget.isDark ? AppColors.surface : AppColors.surfaceLight;
        final highlight = widget.isDark
            ? AppColors.surfaceElevated
            : AppColors.surfaceElevatedLight;
        final border = widget.isDark ? AppColors.border : AppColors.borderLight;
        final shimmer = Color.lerp(base, highlight, _shimmer.value)!;
        return widget.builder(
          context,
          ShimmerColors(shimmer: shimmer, border: border),
        );
      },
    );
  }
}

/// A rounded-rect placeholder — a "line of text" or any solid block.
class ShimmerBlock extends StatelessWidget {
  const ShimmerBlock({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 6,
    required this.color,
  });

  final double? width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A circular placeholder — an avatar/emoji/icon slot.
class ShimmerCircle extends StatelessWidget {
  const ShimmerCircle({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

/// A rounded-rect card shell with the pulsing [ShimmerColors.shimmer] fill
/// and a static border — the outer container most skeleton rows/cards use.
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({
    super.key,
    required this.colors,
    required this.child,
    this.height,
    this.padding = const EdgeInsets.all(14),
    this.radius = 12,
  });

  final ShimmerColors colors;
  final Widget child;
  final double? height;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.shimmer,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: child,
    );
  }
}
