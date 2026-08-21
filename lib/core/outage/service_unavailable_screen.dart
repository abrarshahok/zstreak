import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import 'app_status.dart';
import 'app_status_providers.dart';

/// Shown when [AppHealthState.maintenance] or [AppHealthState.backendUnavailable]
/// is active. Displays a professional, friendly message and a retry button.
///
/// Design principles:
///   - Consistent with ZStreak's dark/light design system (Outfit font, accent
///     violet, neutral surfaces).
///   - No technical error details exposed to users.
///   - Accessible: large tap targets, sufficient contrast.
///   - Responsive: works on any screen size.
class ServiceUnavailableScreen extends ConsumerStatefulWidget {
  const ServiceUnavailableScreen({super.key, required this.status});

  final AppStatus status;

  @override
  ConsumerState<ServiceUnavailableScreen> createState() =>
      _ServiceUnavailableScreenState();
}

class _ServiceUnavailableScreenState
    extends ConsumerState<ServiceUnavailableScreen>
    with SingleTickerProviderStateMixin {
  bool _isRetrying = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);
    // Reset the circuit breaker and health state so the next real Firebase
    // request can probe whether the backend has recovered.
    ref.read(appHealthProvider.notifier).reset();
    if (mounted) setState(() => _isRetrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.background : AppColors.backgroundLight;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Animated illustration ──────────────────────────────────
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: _StatusIllustration(
                    accent: accent,
                    surface: surface,
                    border: border,
                  ),
                ),

                const SizedBox(height: 40),

                // ── App branding ───────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Z',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: accent,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Streak',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ── Title ──────────────────────────────────────────────────
                Text(
                  widget.status.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 16),

                // ── Message ────────────────────────────────────────────────
                Text(
                  widget.status.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: textMuted,
                    height: 1.6,
                  ),
                ),

                // ── Estimated return time (optional) ──────────────────────
                if (widget.status.estimatedReturnTime != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule_rounded, size: 16, color: accent),
                        const SizedBox(width: 8),
                        Text(
                          'Expected back: ${widget.status.estimatedReturnTime}',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                // ── Retry button ───────────────────────────────────────────
                if (widget.status.retryEnabled)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isRetrying ? null : _retry,
                      child: _isRetrying
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            )
                          : const Text('Try Again'),
                    ),
                  ),

                const SizedBox(height: 16),

                // ── Status indicator ───────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300), // amber status dot
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Service status: investigating',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom illustration widget — a stylised "signal/wifi" icon with
/// concentric arcs to convey "connectivity issue" without being alarming.
/// Uses only Flutter primitives — no external image assets required.
class _StatusIllustration extends StatelessWidget {
  const _StatusIllustration({
    required this.accent,
    required this.surface,
    required this.border,
  });

  final Color accent;
  final Color surface;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: surface,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.5),
      ),
      child: Center(
        child: CustomPaint(
          size: const Size(64, 64),
          painter: _WifiOutagePainter(accent: accent, border: border),
        ),
      ),
    );
  }
}

class _WifiOutagePainter extends CustomPainter {
  const _WifiOutagePainter({required this.accent, required this.border});

  final Color accent;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 4;

    final dimPaint = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final accentPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Draw three arcs — outer two dimmed, inner one accented.
    _drawArc(canvas, cx, cy, 28, dimPaint);
    _drawArc(canvas, cx, cy, 18, dimPaint);
    _drawArc(canvas, cx, cy, 8, accentPaint);

    // Center dot.
    canvas.drawCircle(Offset(cx, cy), 3, Paint()..color = accent);

    // Diagonal "X" slash across the outer arc to indicate outage.
    final slashPaint = Paint()
      ..color = accent.withValues(alpha: 0.7)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx + 18, cy - 22),
      Offset(cx + 32, cy - 8),
      slashPaint,
    );
    canvas.drawLine(
      Offset(cx + 32, cy - 22),
      Offset(cx + 18, cy - 8),
      slashPaint,
    );
  }

  void _drawArc(Canvas canvas, double cx, double cy, double r, Paint paint) {
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -2.4, // start angle (radians) — upper-left
      1.8, // sweep angle — roughly 103°
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_WifiOutagePainter old) =>
      old.accent != accent || old.border != border;
}
