import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/local_date.dart';
import '../application/habit_providers.dart';
import '../domain/mood_entry.dart';

/// "How are you feeling today?" — a lightweight, whole-day mood/energy log
/// shown on Home, independent of any one habit. Collapses to a small chip
/// once today is logged; tapping the chip reopens it for editing. Feeds
/// the Analytics "Mood & Consistency" correlation section.
class MoodCard extends ConsumerWidget {
  const MoodCard({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = todayLocalDateString();
    final entry = ref.watch(moodEntryProvider(today)).valueOrNull;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final hasNote = entry?.note != null && entry!.note!.trim().isNotEmpty;

    if (entry != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: GestureDetector(
          onTap: () => _openMoodSheet(context, ref, today, entry),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border, width: 1),
            ),
            child: Row(
              children: [
                Text(
                  MoodEntry.moodEmoji[entry.moodScore - 1],
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s mood logged',
                        style: TextStyle(color: textMuted, fontSize: 12.5),
                      ),
                      if (hasNote) ...[
                        const SizedBox(height: 2),
                        Text(
                          entry.note!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: textPrimary, fontSize: 11.5),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.edit_outlined, size: 14, color: textMuted),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(delay: 60.ms);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
        onTap: () => _openMoodSheet(context, ref, today, null),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How are you feeling today?',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  5,
                  (i) => Text(
                    MoodEntry.moodEmoji[i],
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 60.ms);
  }

  /// Tapping the row above — logged or not — opens this same sheet, so
  /// there's exactly one place a mood (and its optional note) gets written,
  /// instead of an instant tap-to-log path that could never capture a note.
  Future<void> _openMoodSheet(
    BuildContext context,
    WidgetRef ref,
    String date,
    MoodEntry? entry,
  ) async {
    final isDarkNow = Theme.of(context).brightness == Brightness.dark;
    final surface = isDarkNow ? AppColors.surface : AppColors.surfaceLight;
    final surfaceElevated = isDarkNow
        ? AppColors.surfaceElevated
        : AppColors.surfaceElevatedLight;
    final textPrimary = isDarkNow
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDarkNow
        ? AppColors.textMuted
        : AppColors.textMutedLight;
    final accent = isDarkNow ? AppColors.accent : AppColors.accentTextOnLight;
    int selected = entry?.moodScore ?? 0;
    final noteController = TextEditingController(text: entry?.note ?? '');

    await showModalBottomSheet<void>(
      context: context,
      // Same as every other sheet in the app (emoji/color/category
      // pickers) — without this, the sheet doesn't size itself to its
      // own content the way those do and reads as a different, smaller
      // kind of popup instead of a proper full modal sheet.
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 +
                MediaQuery.of(sheetContext).viewInsets.bottom +
                MediaQuery.of(sheetContext).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag-handle bar — the same visual signal every other
              // sheet in the app opens with.
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: textMuted.withValues(alpha: 0.4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                entry == null
                    ? 'How are you feeling today?'
                    : 'Update today\'s mood',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(5, (i) {
                  final score = i + 1;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selected = score),
                    child: AnimatedOpacity(
                      opacity: selected == score ? 1 : 0.4,
                      duration: const Duration(milliseconds: 150),
                      child: Text(
                        MoodEntry.moodEmoji[i],
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              Text(
                'Add a reason or note (optional)',
                style: TextStyle(
                  color: textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                minLines: 1,
                maxLines: 3,
                maxLength: 200,
                style: TextStyle(color: textPrimary, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'What\'s behind this mood?',
                  hintStyle: TextStyle(
                    color: textMuted.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: surfaceElevated,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selected == 0
                      ? null
                      : () async {
                          final noteText = noteController.text.trim();
                          await ref
                              .read(moodRepositoryProvider)
                              .logMood(
                                date: date,
                                moodScore: selected,
                                note: noteText.isEmpty ? null : noteText,
                              );
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    entry == null ? 'Save' : 'Save changes',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
