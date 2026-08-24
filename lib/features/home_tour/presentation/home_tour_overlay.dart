import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../../core/theme/app_theme.dart';
import '../../habits/application/habit_providers.dart';
import '../application/home_tour_providers.dart';

/// True once any [HomeTourOverlay] instance has attempted the tour this
/// process lifetime — see the guard in [_HomeTourOverlayState._maybeShowTour]
/// for why this needs to live outside any single instance's state.
bool _tourAttemptedThisSession = false;

/// Wraps [HomeScreen]'s Scaffold and, the first time Home is ever shown,
/// fires a spotlight walkthrough over the Add Habit button, the first
/// habit card (if one exists yet), and the header icons — see
/// home_tour_providers.dart for the seen-flag and shared GlobalKeys this
/// depends on.
///
/// A plain passthrough otherwise: this widget's only job is owning the
/// `initState` lifecycle hook a `ConsumerWidget` like [HomeScreen] doesn't
/// have, so the tour fires exactly once per install without having to
/// convert the whole (1600+ line) HomeScreen to stateful.
class HomeTourOverlay extends ConsumerStatefulWidget {
  const HomeTourOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<HomeTourOverlay> createState() => _HomeTourOverlayState();
}

class _HomeTourOverlayState extends ConsumerState<HomeTourOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTour());
  }

  Future<void> _maybeShowTour() async {
    // Guards against two HomeTourOverlay instances existing in quick
    // succession (e.g. a transient rebuild of the guest/entitlement gates
    // above Home right after cold start) both reading homeTourSeenProvider
    // as false before either has finished and marked it seen — which
    // played the whole tour twice back to back. This check-then-set is
    // synchronous (no await before it), so only the first instance to
    // reach it ever proceeds, regardless of how the seen-flag write times
    // out relative to a second instance's own check.
    if (_tourAttemptedThisSession) return;
    _tourAttemptedThisSession = true;

    if (ref.read(homeTourSeenProvider)) return;

    // Waits for the stream's first real emission rather than reading
    // whatever's cached right now — right after a cold start that can
    // still be an empty AsyncLoading snapshot even for a user who
    // actually has habits, which would wrongly skip the habit-card step.
    final habits = await ref.read(activeHabitsProvider.future);
    if (!mounted) return;

    final keys = ref.read(homeTourKeysProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;

    final steps = <TargetFocus>[
      _step(
        key: keys.fabKey,
        accent: accent,
        isDark: isDark,
        radius: 24,
        title: 'Add a habit',
        body:
            "Tap here to add your first habit — that's how everything "
            'on this screen gets started.',
      ),
      if (habits.isNotEmpty)
        _step(
          key: keys.firstHabitKey,
          accent: accent,
          isDark: isDark,
          title: 'Your habits',
          body:
              'Tap a habit to check it off for today, or see its full '
              'history and streak.',
        ),
      _step(
        key: keys.viewToggleKey,
        accent: accent,
        isDark: isDark,
        title: 'Switch views',
        body: 'Toggle between list and grid layout for your habits.',
      ),
      _step(
        key: keys.analyticsKey,
        accent: accent,
        isDark: isDark,
        title: 'Analytics',
        body: 'See your consistency trends and progress over time.',
      ),
      _step(
        key: keys.archiveKey,
        accent: accent,
        isDark: isDark,
        title: 'Archive',
        body: 'Habits you pause instead of delete end up here.',
      ),
      _step(
        key: keys.settingsKey,
        accent: accent,
        isDark: isDark,
        title: 'Settings',
        body: 'Manage your account, theme, and Pro subscription.',
      ),
    ];

    if (!mounted) return;
    TutorialCoachMark(
      targets: steps,
      colorShadow: Colors.black,
      opacityShadow: 0.78,
      paddingFocus: 6,
      hideSkip: false,
      textSkip: 'Skip',
      alignSkip: Alignment.topRight,
      textStyleSkip: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      onFinish: () => markHomeTourSeen(ref),
      onSkip: () {
        markHomeTourSeen(ref);
        return true;
      },
    ).show(context: context);
  }

  TargetFocus _step({
    required GlobalKey key,
    required Color accent,
    required bool isDark,
    required String title,
    required String body,
    double radius = 14,
  }) {
    return TargetFocus(
      keyTarget: key,
      shape: ShapeLightFocus.RRect,
      radius: radius,
      color: accent,
      contents: [
        TargetContent(
          align: _alignFor(key),
          builder: (context, controller) => _TourCard(
            title: title,
            body: body,
            isDark: isDark,
            accent: accent,
            onNext: controller.next,
          ),
        ),
      ],
    );
  }

  /// Picks which side of the target to show the card on based on the
  /// target's *actual* position on screen, rather than a hardcoded guess
  /// per step. A hardcoded `ContentAlign.bottom` on a target that's
  /// already in the lower half of the screen (e.g. the header icons on a
  /// short device, or the FAB) pushed the card past the bottom edge —
  /// this keeps it on whichever side actually has room.
  ContentAlign _alignFor(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return ContentAlign.bottom;
    final targetTop = box.localToGlobal(Offset.zero).dy;
    final targetCenterY = targetTop + box.size.height / 2;
    final screenHeight = MediaQuery.of(context).size.height;
    return targetCenterY > screenHeight * 0.6
        ? ContentAlign.top
        : ContentAlign.bottom;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ─── Tour content card ────────────────────────────────────────────────────────

class _TourCard extends StatelessWidget {
  const _TourCard({
    required this.title,
    required this.body,
    required this.isDark,
    required this.accent,
    required this.onNext,
  });

  final String title;
  final String body;
  final bool isDark;
  final Color accent;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = isDark ? AppColors.surface : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.border : AppColors.borderLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(color: textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          // A fixed height here clipped the label at larger system font
          // scales (the button's intrinsic content — text + padding —
          // could exceed it). minHeight keeps the tap target a reasonable
          // size without ever cutting the text off.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Got it',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
