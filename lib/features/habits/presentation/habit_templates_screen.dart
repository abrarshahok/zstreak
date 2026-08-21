import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/color_hex.dart';
import '../../monetization/application/entitlement_providers.dart';
import '../../monetization/presentation/paywall_navigation.dart';
import '../domain/frequency.dart';
import '../domain/habit_template.dart';
import 'edit_habit_screen.dart';

// ─── Free template limit ──────────────────────────────────────────────────────

/// Free users may use the first [kFreeTemplateLimit] templates.
/// Templates beyond this index require a Pro subscription.
const int kFreeTemplateLimit = 3;

// ─── Habit Templates Screen ───────────────────────────────────────────────────

class HabitTemplatesScreen extends ConsumerStatefulWidget {
  const HabitTemplatesScreen({super.key});

  @override
  ConsumerState<HabitTemplatesScreen> createState() =>
      _HabitTemplatesScreenState();
}

class _HabitTemplatesScreenState extends ConsumerState<HabitTemplatesScreen> {
  TemplateCategory? _selectedCategory;

  List<HabitTemplate> get _filtered {
    if (_selectedCategory == null) return kHabitTemplates;
    return kHabitTemplates
        .where((t) => t.category == _selectedCategory)
        .toList();
  }

  Future<void> _openTemplate(
    HabitTemplate template, {
    required bool isPro,
  }) async {
    if (!isPro) {
      // Check if this template is beyond the free limit in the full list.
      final globalIndex = kHabitTemplates.indexOf(template);
      if (globalIndex >= kFreeTemplateLimit) {
        await navigateToPaywall(context, ref);
        return;
      }
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditHabitScreen(template: template)),
    );
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

    // Resolve entitlement — default to free while loading.
    final isPro = ref.watch(hasActiveEntitlementProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Template Library',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (!isPro)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => navigateToPaywall(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : AppColors.accentTextOnLight.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? AppColors.accent.withValues(alpha: 0.4)
                          : AppColors.accentTextOnLight.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 11,
                        color: isDark
                            ? AppColors.accent
                            : AppColors.accentTextOnLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pro',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.accent
                              : AppColors.accentTextOnLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: border),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Category filter chips ──────────────────────────────────────────
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                _CategoryChip(
                  label: 'All',
                  emoji: '✨',
                  selected: _selectedCategory == null,
                  isDark: isDark,
                  onTap: () => setState(() => _selectedCategory = null),
                ),
                const SizedBox(width: 8),
                ...TemplateCategory.values.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _CategoryChip(
                      label: cat.label,
                      emoji: cat.emoji,
                      selected: _selectedCategory == cat,
                      isDark: isDark,
                      onTap: () => setState(
                        () => _selectedCategory = _selectedCategory == cat
                            ? null
                            : cat,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // ── Divider ───────────────────────────────────────────────────────
          Container(height: 1, color: border),

          // ── Template list ─────────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: _filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final template = _filtered[index];
                // A template is locked if the user is free AND its global
                // index in kHabitTemplates is >= kFreeTemplateLimit.
                final globalIndex = kHabitTemplates.indexOf(template);
                final isLocked = !isPro && globalIndex >= kFreeTemplateLimit;
                return _TemplateCard(
                      template: template,
                      isDark: isDark,
                      surface: surface,
                      border: border,
                      textPrimary: textPrimary,
                      textMuted: textMuted,
                      isLocked: isLocked,
                      onTap: () => _openTemplate(template, isPro: isPro),
                    )
                    .animate()
                    .fadeIn(delay: (30 * index).ms)
                    .slideY(
                      begin: 0.06,
                      duration: 220.ms,
                      curve: Curves.easeOut,
                    );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Category Chip ────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? AppColors.accent : AppColors.accentTextOnLight;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? accent : surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? accent : border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? (isDark ? Colors.black : Colors.white)
                    : textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Template Card ────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.isDark,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
    required this.isLocked,
    required this.onTap,
  });

  final HabitTemplate template;
  final bool isDark;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textMuted;
  final bool isLocked;
  final VoidCallback onTap;

  String get _frequencyLabel {
    switch (template.frequencyType) {
      case FrequencyType.daily:
        return 'Daily';
      case FrequencyType.weekdays:
        final days = template.weekdays ?? [1, 2, 3, 4, 5];
        if (days.length == 5 &&
            days.contains(1) &&
            days.contains(5) &&
            !days.contains(6)) {
          return 'Weekdays';
        }
        const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days.map((d) => names[d - 1]).join(', ');
      case FrequencyType.xPerWeek:
        final n = template.timesPerWeek ?? 3;
        return '$n× per week';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = colorFromHex(template.colorHex);
    final lockedOverlay = isDark
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.55);
    final proAccent = isDark ? AppColors.accent : AppColors.accentTextOnLight;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // ── Card body ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isLocked ? proAccent.withValues(alpha: 0.25) : border,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // ── Emoji badge ────────────────────────────────────────────
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isDark ? 0.15 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      template.emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // ── Name + meta ────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.name,
                        style: TextStyle(
                          color: isLocked ? textMuted : textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isLocked ? textMuted : accentColor,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _frequencyLabel,
                            style: TextStyle(
                              color: textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              template.category.label,
                              style: TextStyle(
                                color: textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // ── Use / Lock button ──────────────────────────────────────
                if (isLocked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: proAccent.withValues(alpha: isDark ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: proAccent.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded, size: 11, color: proAccent),
                        const SizedBox(width: 4),
                        Text(
                          'Pro',
                          style: TextStyle(
                            color: proAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: isDark ? 0.15 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Use',
                      style: TextStyle(
                        color: readableAccent(
                          accentColor,
                          fallback: textPrimary,
                        ),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Frosted lock overlay (subtle dimming only, no blur) ────────────
          if (isLocked)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: lockedOverlay,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
