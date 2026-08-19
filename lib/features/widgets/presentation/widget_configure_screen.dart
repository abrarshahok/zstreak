import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../../core/theme/app_theme.dart';
import '../../habits/application/habit_providers.dart';
import '../application/widget_providers.dart';

/// Shown instead of the normal app when Android launches us via the
/// widget's configuration intent (spec Section 2's "widget configuration
/// Activity that appears the moment a user drags the widget onto their
/// home screen"). Picking a habit here persists it per widget-instance-id,
/// not globally, since a user may place several widgets for different
/// habits.
class WidgetConfigureScreen extends ConsumerWidget {
  const WidgetConfigureScreen({super.key, required this.widgetId});

  final int widgetId;

  Future<void> _choose(WidgetRef ref, String habitId) async {
    await ref.read(widgetSyncServiceProvider).setWidgetHabit(widgetId, habitId);
    await HomeWidget.finishHomeWidgetConfigure();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(activeHabitsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.background : AppColors.backgroundLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: textPrimary,
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
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
        loading: () => Center(
          child: CircularProgressIndicator(
            color: isDark ? AppColors.accent : AppColors.accentTextOnLight,
            strokeWidth: 2,
          ),
        ),
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
                onTap: () => _choose(ref, habit.id),
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
