import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../../../core/theme/app_theme.dart';
import '../../habits/application/habit_providers.dart';
import '../application/home_tour_providers.dart';

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
        align: ContentAlign.top,
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
          align: ContentAlign.bottom,
          title: 'Your habits',
          body:
              'Tap a habit to check it off for today, or see its full '
              'history and streak.',
        ),
      _step(
        key: keys.viewToggleKey,
        accent: accent,
        isDark: isDark,
        align: ContentAlign.bottom,
        title: 'Switch views',
        body: 'Toggle between list and grid layout for your habits.',
      ),
      _step(
        key: keys.analyticsKey,
        accent: accent,
        isDark: isDark,
        align: ContentAlign.bottom,
        title: 'Analytics',
        body: 'See your consistency trends and progress over time.',
      ),
      _step(
        key: keys.archiveKey,
        accent: accent,
        isDark: isDark,
        align: ContentAlign.bottom,
        title: 'Archive',
        body: 'Habits you pause instead of delete end up here.',
      ),
      _step(
        key: keys.settingsKey,
        accent: accent,
        isDark: isDark,
        align: ContentAlign.bottom,
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
    required ContentAlign align,
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
          align: align,
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
          SizedBox(
            width: double.infinity,
            height: 40,
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
        ],
      ),
    );
  }
}
