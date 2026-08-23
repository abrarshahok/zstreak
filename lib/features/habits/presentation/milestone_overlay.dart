import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/prefs/shared_preferences_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/color_hex.dart';
import '../domain/habit.dart';

// ─── Milestone definitions ────────────────────────────────────────────────────

const List<int> kStreakMilestones = [3, 7, 14, 21, 30, 50, 66, 100];

String _milestoneEmoji(int days) {
  if (days >= 100) return '🏆';
  if (days >= 66) return '💎';
  if (days >= 50) return '🌟';
  if (days >= 30) return '🔥';
  if (days >= 21) return '⚡';
  if (days >= 14) return '💪';
  if (days >= 7) return '🎯';
  return '✨';
}

String _milestoneMessage(int days) {
  switch (days) {
    case 3:
      return 'Three days in. The habit is forming.';
    case 7:
      return 'One full week. You\'re building something real.';
    case 14:
      return 'Two weeks strong. Consistency is your superpower.';
    case 21:
      return '21 days. Science says it\'s a habit now.';
    case 30:
      return 'A whole month. You\'re unstoppable.';
    case 50:
      return '50 days. Half a century of showing up.';
    case 66:
      return '66 days. The research says you\'re wired in.';
    case 100:
      return '100 days. Legendary. Absolutely legendary.';
    default:
      return 'Keep going. Every day counts.';
  }
}

// ─── SharedPreferences key helpers ───────────────────────────────────────────

const String _kShownMilestonesKey = 'shownMilestones';

/// Returns the set of "habitId:milestone" strings already shown.
Set<String> _getShownMilestones(SharedPreferences prefs) {
  return prefs.getStringList(_kShownMilestonesKey)?.toSet() ?? {};
}

/// Marks a milestone as shown so it won't appear again.
Future<void> _markMilestoneShown(
  SharedPreferences prefs,
  String habitId,
  int milestone,
) async {
  final key = '$habitId:$milestone';
  final current = _getShownMilestones(prefs);
  current.add(key);
  await prefs.setStringList(_kShownMilestonesKey, current.toList());
}

/// Returns true if this milestone has NOT been shown yet for this habit.
bool _isMilestoneNew(SharedPreferences prefs, String habitId, int milestone) {
  final key = '$habitId:$milestone';
  return !_getShownMilestones(prefs).contains(key);
}

// ─── Public helper: check and show milestone after check-in ──────────────────

/// Call this after a successful check-in. If [streak] is a milestone and
/// hasn't been shown yet, shows the full-screen overlay.
Future<void> maybeShowMilestoneOverlay({
  required BuildContext context,
  required WidgetRef ref,
  required Habit habit,
  required int streak,
}) async {
  if (!kStreakMilestones.contains(streak)) return;

  final prefs = ref.read(sharedPreferencesProvider);
  if (!_isMilestoneNew(prefs, habit.id, streak)) return;

  // Mark as shown before displaying to prevent double-show on rapid taps.
  await _markMilestoneShown(prefs, habit.id, streak);

  if (!context.mounted) return;

  HapticFeedback.heavyImpact();

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 350),
    transitionBuilder: (ctx, anim, _, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      );
    },
    pageBuilder: (ctx, _, _) => _MilestoneOverlay(habit: habit, streak: streak),
  );
}

// ─── Overlay widget ───────────────────────────────────────────────────────────

class _MilestoneOverlay extends StatefulWidget {
  const _MilestoneOverlay({required this.habit, required this.streak});

  final Habit habit;
  final int streak;

  @override
  State<_MilestoneOverlay> createState() => _MilestoneOverlayState();
}

class _MilestoneOverlayState extends State<_MilestoneOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _countController;
  late final Animation<double> _countAnim;
  int _displayCount = 0;
  Timer? _countTimer;
  final GlobalKey _shareKey = GlobalKey();
  bool _isSharing = false;

  /// Captures the [RepaintBoundary]-wrapped card below (emoji through the
  /// motivational message — not the dismiss button) as a PNG and hands it
  /// to the OS share sheet, mirroring the exact temp-file + share_plus
  /// pattern `DataExporter.shareCsv()` already uses.
  Future<void> _shareAsImage() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final boundary =
          _shareKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/zstreak_milestone_${widget.habit.id}_${widget.streak}.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text:
              '${widget.streak}-day streak on ${widget.habit.name} ${widget.habit.emoji} - built with ZStreak',
        ),
      );
    } catch (_) {
      // No user-visible surface for a share failure here — the OS share
      // sheet itself communicates success; silently no-op on failure.
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _countController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _countAnim = CurvedAnimation(
      parent: _countController,
      curve: Curves.easeOut,
    );

    _countAnim.addListener(() {
      final val = (_countAnim.value * widget.streak).round();
      if (val != _displayCount) {
        setState(() => _displayCount = val);
      }
    });

    // Small delay before starting count-up so the overlay entrance is visible.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _countController.forward();
    });
  }

  @override
  void dispose() {
    _countController.dispose();
    _countTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = colorFromHex(widget.habit.colorHex);

    // Tinted background: accent at low opacity over the theme background.
    final bgBase = isDark ? AppColors.background : AppColors.backgroundLight;
    final tintedBg = Color.alphaBlend(
      accentColor.withValues(alpha: isDark ? 0.12 : 0.07),
      bgBase,
    );

    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;

    final emoji = _milestoneEmoji(widget.streak);
    final message = _milestoneMessage(widget.streak);

    return Material(
      color: tintedBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Wrapped in a RepaintBoundary so a tap on the share button
              // below can capture exactly this card (not the dismiss
              // button or the surrounding Spacers) as a shareable PNG.
              RepaintBoundary(
                key: _shareKey,
                child: Container(
                  color: tintedBg,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Habit emoji ──────────────────────────────────────
                      Text(
                            widget.habit.emoji,
                            style: const TextStyle(fontSize: 48),
                          )
                          .animate()
                          .fadeIn(delay: 100.ms, duration: 400.ms)
                          .scale(
                            begin: const Offset(0.6, 0.6),
                            end: const Offset(1.0, 1.0),
                            duration: 500.ms,
                            curve: Curves.easeOutBack,
                          ),

                      const SizedBox(height: 24),

                      // ── Count-up number ───────────────────────────────────
                      Text(
                        '$_displayCount',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 96,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -4,
                          height: 1,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // ── "day streak" label ────────────────────────────────
                      Text(
                        'day streak',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.3,
                        ),
                      ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                      const SizedBox(height: 32),

                      // ── Milestone emoji badge ─────────────────────────────
                      Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: accentColor.withValues(
                                alpha: isDark ? 0.15 : 0.10,
                              ),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  widget.habit.name,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 400.ms, duration: 400.ms)
                          .slideY(
                            begin: 0.15,
                            end: 0,
                            delay: 400.ms,
                            duration: 400.ms,
                            curve: Curves.easeOut,
                          ),

                      const SizedBox(height: 28),

                      // ── Motivational message ──────────────────────────────
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textMuted,
                          fontSize: 16,
                          height: 1.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Share button ──────────────────────────────────────────────
              TextButton.icon(
                onPressed: _isSharing ? null : _shareAsImage,
                icon: _isSharing
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accentColor,
                        ),
                      )
                    : Icon(
                        Icons.ios_share_rounded,
                        size: 16,
                        color: accentColor,
                      ),
                label: Text(
                  'Share this streak',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ).animate().fadeIn(delay: 700.ms, duration: 400.ms),

              const Spacer(flex: 2),

              // ── Dismiss button ───────────────────────────────────────────
              SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textPrimary,
                        side: BorderSide(color: border, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.transparent,
                      ),
                      child: Text(
                        'Keep going →',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 800.ms, duration: 400.ms)
                  .slideY(
                    begin: 0.2,
                    end: 0,
                    delay: 800.ms,
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
