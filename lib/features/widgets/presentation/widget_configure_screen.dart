import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../habits/application/habit_providers.dart';
import '../../monetization/application/entitlement_providers.dart';
import '../../monetization/presentation/paywall_navigation.dart';
import '../application/widget_providers.dart';

/// Shown instead of the normal app when Android launches us via the
/// widget's configuration intent (spec Section 2's "widget configuration
/// Activity that appears the moment a user drags the widget onto their
/// home screen"). Picking a habit here persists it per widget-instance-id,
/// not globally, since a user may place several widgets for different
/// habits.
///
/// This fires on *every* widget placement, regardless of how it was
/// started — including Android's own system widget picker, which has no
/// idea the app's Settings screen gates "Add home screen widget" behind
/// Pro. Gating happens here instead, at the one place Android always
/// routes through: if the user isn't Pro, this never shows the habit list
/// or calls [HomeWidget.finishHomeWidgetConfigure], so Android cancels the
/// placement — there is no way to end up with a working widget for free.
class WidgetConfigureScreen extends ConsumerWidget {
  const WidgetConfigureScreen({super.key, required this.widgetId});

  final int widgetId;

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    String habitId,
  ) async {
    // setWidgetHabit() only persists the widget-instance→habit mapping —
    // it never writes the habit's own display fields (name/emoji/streak/
    // completed) or premium_active, both of which are otherwise only
    // ever written as a side effect of a *later* check-in/edit on that
    // specific habit. Without this, a freshly-placed widget for a habit
    // that hasn't been touched since install renders as either the
    // locked "Subscription expired" state (premium_active defaults to
    // false) or generic placeholder text ("⭐ Habit · 0 day streak"),
    // even though the widget-to-habit mapping itself is correct.
    final repo = ref.read(habitRepositoryProvider);
    final habit = await repo.getHabitById(habitId);
    if (habit != null) {
      final isPremium = await ref.read(hasActiveEntitlementProvider.future);
      await ref
          .read(widgetSyncServiceProvider)
          .syncSingleHabit(
            habit,
            (id, date) => repo.watchCheckIn(habitId: id, date: date).first,
            (id) => repo.watchHabitCheckIns(id).first,
            isPremium: isPremium,
          );
    }
    await ref.read(widgetSyncServiceProvider).setWidgetHabit(widgetId, habitId);

    // Two different ways this screen shows up, and each needs a different
    // "done": as the Activity's own home (a manual OS widget-tray add via
    // android:configure), where finishHomeWidgetConfigure() finishes that
    // Activity so the widget host gets its RESULT_OK — or pushed as a
    // normal route (Settings' "Add home screen widget" button, via the
    // pin-confirmed callback in app.dart), where finishHomeWidgetConfigure
    // is a silent no-op (its native guard only fires for the configure
    // intent's own action) and this needs to just pop back instead.
    if (!context.mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      await HomeWidget.finishHomeWidgetConfigure();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This screen is main.dart's `home` for the entire lifetime of an
    // app launch that started from the widget's configure intent — AuthGate
    // (the only other place that calls this) never mounts on that launch
    // path, so without this the native splash held by preserve() would
    // never be released.
    FlutterNativeSplash.remove();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.background : AppColors.backgroundLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;

    // This screen can be main.dart's very first `home` on a cold start
    // from the widget's configure intent, before RevenueCat has ever
    // resolved a customer info — valueOrNull collapsing that "still
    // loading" state to false used to flash the Pro-lock screen at a
    // real Pro user before flipping to the actual habit picker once the
    // entitlement check caught up.
    final entitlement = ref.watch(hasActiveEntitlementProvider);
    final isPro = entitlement.valueOrNull ?? false;
    final backButton = Navigator.of(context).canPop()
        ? IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: textPrimary,
            ),
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
          )
        : null;

    if (entitlement.isLoading && !entitlement.hasValue) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: backButton,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!isPro) {
      return Scaffold(
        backgroundColor: bgColor,
        // Previously had no AppBar at all — reachable pushed as a normal
        // route (Settings' "Add home screen widget"), where a non-Pro
        // user had no way to dismiss this except tapping "Unlock Pro" or
        // an OS back gesture.
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: backButton,
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.12),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Icon(
                      Icons.widgets_outlined,
                      color: accent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Home screen widgets are Pro',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Upgrade to add a live streak widget to your home screen. This one won't be placed until you do.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () => navigateToPaywall(context, ref),
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Unlock Pro',
                          style: TextStyle(
                            color: isDark ? Colors.black : Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final habits = ref.watch(activeHabitsProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: backButton,
        title: Text(
          'Choose habit for widget',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: border),
        ),
      ),
      body: habits.when(
        loading: () => _WidgetHabitListSkeleton(isDark: isDark),
        error: (error, _) => Center(
          child: Text('$error', style: TextStyle(color: textMuted)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Create a habit first, then add the widget again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textMuted, fontSize: 14, height: 1.5),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final habit = list[index];
              return GestureDetector(
                onTap: () => _choose(context, ref, habit.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border, width: 1),
                  ),
                  child: Row(
                    children: [
                      Text(habit.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          habit.name,
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: textMuted,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Loading skeleton ─────────────────────────────────────────────────────────

class _WidgetHabitListSkeleton extends StatelessWidget {
  const _WidgetHabitListSkeleton({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      isDark: isDark,
      builder: (context, colors) {
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: 6,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) => ShimmerCard(
            colors: colors,
            radius: 10,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                ShimmerCircle(size: 22, color: colors.border),
                const SizedBox(width: 12),
                Expanded(child: ShimmerBlock(height: 14, color: colors.border)),
                const SizedBox(width: 12),
                ShimmerCircle(size: 18, color: colors.border),
              ],
            ),
          ),
        );
      },
    );
  }
}
