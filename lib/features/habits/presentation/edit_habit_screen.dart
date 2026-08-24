import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart'
    hide colorFromHex, colorToHex;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/copy/app_copy.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snack_bar.dart';
import '../../../core/utils/color_hex.dart';
import '../../../core/widgets/flat_confirm_dialog.dart';
import '../../analytics/analytics_service.dart';
import '../../monetization/application/entitlement_providers.dart';
import '../../monetization/presentation/paywall_navigation.dart';
import '../../notifications/application/notification_providers.dart';
import '../application/habit_providers.dart';
import '../domain/frequency.dart';
import '../domain/habit.dart';
import 'edit_habit_widgets.dart';

const List<String> _emojiChoices = [
  // Health & Fitness
  '💪', '🏃', '🚴', '🏋️', '🤸', '🧘', '🏊', '⛹️', '🤾', '🚶',
  '🥊', '🏇', '🧗', '🤺', '🏄', '🎽', '🦵', '❤️‍🔥',
  // Food & Drink
  '🥗', '💧', '🍎', '🥦', '🍵', '☕', '🥤', '🍳', '🥑', '🫐',
  '🍇', '🥕', '🫖', '🍋', '🧃',
  // Mind & Learning
  '📚', '✍️', '🎯', '🧠', '📖', '🖊️', '📝', '🔬', '💡', '🎓',
  '🗣️', '🧩', '📐', '🔭',
  // Sleep & Rest
  '😴', '🌙', '🛌', '💤', '🌟',
  // Creativity & Hobbies
  '🎸', '🎹', '🎨', '✏️', '📷', '🎬', '🎭', '🎤', '🎻', '🥁',
  '🖌️', '🎮', '♟️', '🎲', '🪴', '🌱',
  // Wellness & Lifestyle
  '🧹', '🪥', '🚭', '🍷', '🧴', '🛁', '🪞', '🌿', '🕯️', '💊',
  // Finance & Productivity
  '💰', '📊', '📅', '⏰', '✅', '🗓️', '📌', '🔑', '💼', '🏦',
  // Social & Relationships
  '📞', '💌', '🤝', '😊', '🫂',
  // Nature & Outdoors
  '☀️', '🌳', '🐕', '🌊', '⛰️', '🌸', '🦋',
  // Symbols & Misc
  '⭐', '🔥', '⚡', '🏆', '🎖️', '🚀', '💎', '🌈',
];

// 26 colors, swept around the hue wheel red → orange → yellow → green →
// teal → cyan → blue → indigo → violet → purple → magenta → pink → back
// toward red — so the picker row reads as one deliberate spectrum rather
// than a random grab bag. No whites, greys, or near-blacks: every entry
// is fully saturated so it stays legible as a habit accent on both light
// and dark surfaces.
const List<Color> _presetColors = [
  Color(0xFFFF4D4D), // red
  Color(0xFFE63950), // crimson
  Color(0xFFFF6B5B), // coral
  Color(0xFFFF6B00), // orange
  Color(0xFFFF9F1C), // tangerine
  Color(0xFFFFB800), // amber
  Color(0xFFFFC24D), // marigold
  Color(0xFFFFD700), // gold
  Color(0xFFC6FF00), // lime
  Color(0xFF7ED321), // grass
  Color(0xFF00C853), // green
  Color(0xFF00FF94), // mint
  Color(0xFF00BFA5), // teal
  Color(0xFF40E0D0), // turquoise
  Color(0xFF00C2FF), // cyan
  Color(0xFF38BDF8), // sky
  Color(0xFF4D9FFF), // blue
  Color(0xFF2962FF), // indigo blue
  Color(0xFF6366F1), // indigo
  Color(0xFF7C3AED), // deep violet
  Color(0xFFB57BFF), // violet — matches app accent
  Color(0xFFA855F7), // purple
  Color(0xFFE040FB), // magenta
  Color(0xFFEC4899), // rose
  Color(0xFFFF4DA6), // pink
  Color(0xFFFF69B4), // hot pink
];

class EditHabitScreen extends ConsumerStatefulWidget {
  const EditHabitScreen({
    super.key,
    this.existing,
    this.isFirstHabit = false,
    this.prefillName,
    this.prefillEmoji,
    this.prefillColorHex,
    this.prefillFrequencyType,
    this.prefillFrequencyConfig,
    this.prefillDescription,
  });
  final Habit? existing;
  final bool isFirstHabit;

  /// Quick-start prefill (Home's empty-state cards) — ignored when
  /// [existing] is non-null. Deliberately just these few loose fields
  /// rather than a shared template model: there are only 3 quick-start
  /// options and no browsable library behind them.
  final String? prefillName;
  final String? prefillEmoji;
  final String? prefillColorHex;
  final FrequencyType? prefillFrequencyType;
  final FrequencyConfig? prefillFrequencyConfig;
  final String? prefillDescription;

  @override
  ConsumerState<EditHabitScreen> createState() => _EditHabitScreenState();
}

class _EditHabitScreenState extends ConsumerState<EditHabitScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late String _emoji;
  late Color _color;
  late FrequencyType _frequencyType;
  late Set<int> _weekdays;
  late int _timesPerWeek;
  TimeOfDay? _reminderTime;
  bool _isSaving = false;
  String? _nameError;

  String? _categoryId;
  bool _isQuantityHabit = false;
  late TextEditingController _targetUnitController;
  int _targetCount = 1;
  bool _isQuitHabit = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final habit = widget.existing;
    // Priority: existing habit > quick-start prefill > defaults.
    _nameController = TextEditingController(
      text: habit?.name ?? widget.prefillName ?? '',
    );
    _descriptionController = TextEditingController(
      text: habit?.description ?? widget.prefillDescription ?? '',
    );
    _emoji = habit?.emoji ?? widget.prefillEmoji ?? _emojiChoices.first;
    _color = habit != null
        ? colorFromHex(habit.colorHex)
        : widget.prefillColorHex != null
        ? colorFromHex(widget.prefillColorHex!)
        : AppColors.accent;
    _frequencyType =
        habit?.frequencyType ??
        widget.prefillFrequencyType ??
        FrequencyType.daily;
    final config = habit?.frequencyConfig ?? widget.prefillFrequencyConfig;
    _weekdays = config is WeekdaysConfig
        ? config.weekdays.toSet()
        : {1, 2, 3, 4, 5};
    _timesPerWeek = config is XPerWeekConfig ? config.timesPerWeek : 3;
    final reminder = habit?.reminderTime;
    if (reminder != null) {
      final parts = reminder.split(':');
      _reminderTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }
    _categoryId = habit?.categoryId;
    _isQuantityHabit = habit?.isQuantityHabit ?? false;
    _targetCount = habit?.targetCount ?? 8;
    _targetUnitController = TextEditingController(
      text: habit?.targetUnit ?? '',
    );
    _isQuitHabit = habit?.isQuitHabit ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetUnitController.dispose();
    super.dispose();
  }

  Future<void> _openEmojiPicker() async {
    var filter = '';
    final searchController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surface : AppColors.surfaceLight;
    final surfaceElevated = isDark
        ? AppColors.surfaceElevated
        : AppColors.surfaceElevatedLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;

    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final filtered = filter.isEmpty
                ? _emojiChoices
                : _emojiChoices.where((e) => e.contains(filter)).toList();
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom:
                    MediaQuery.of(sheetContext).viewInsets.bottom +
                    MediaQuery.of(sheetContext).padding.bottom +
                    20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: textMuted.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Choose an icon',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: searchController,
                    style: TextStyle(color: textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Paste emoji to filter…',
                      hintStyle: TextStyle(
                        color: textMuted.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: textMuted,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _color, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (v) => setSheetState(() => filter = v),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 320,
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final e = filtered[i];
                        final selected = e == _emoji;
                        return GestureDetector(
                          onTap: () => Navigator.of(sheetContext).pop(e),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: selected
                                  ? _color.withValues(alpha: 0.15)
                                  : surfaceElevated,
                              border: Border.all(
                                color: selected ? _color : border,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 19),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    searchController.dispose();
    if (picked != null) setState(() => _emoji = picked);
  }

  Future<void> _openColorPicker() async {
    Color tempColor = _color;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final surfaceColor = isDark
            ? AppColors.surface
            : AppColors.surfaceLight;
        final textPrimary = isDark
            ? AppColors.textPrimary
            : AppColors.textPrimaryLight;
        final textMuted = isDark
            ? AppColors.textMuted
            : AppColors.textMutedLight;
        return StatefulBuilder(
          builder: (ctx, setModalState) => Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom:
                    MediaQuery.of(ctx).viewInsets.bottom +
                    MediaQuery.of(ctx).padding.bottom +
                    24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: textMuted.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Pick a color',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ColorPicker(
                    pickerColor: tempColor,
                    onColorChanged: (c) => setModalState(() => tempColor = c),
                    colorPickerWidth: MediaQuery.of(ctx).size.width - 40,
                    pickerAreaHeightPercent: 0.5,
                    enableAlpha: false,
                    displayThumbColor: true,
                    paletteType: PaletteType.hsvWithHue,
                    labelTypes: const [],
                    pickerAreaBorderRadius: BorderRadius.circular(16),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: tempColor,
                      border: Border.all(
                        color: tempColor.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _color = tempColor);
                        Navigator.of(ctx).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tempColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Apply color',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  FrequencyConfig get _frequencyConfig => switch (_frequencyType) {
    FrequencyType.daily => const DailyConfig(),
    FrequencyType.weekdays => WeekdaysConfig(
      weekdays: _weekdays.toList()..sort(),
    ),
    FrequencyType.xPerWeek => XPerWeekConfig(timesPerWeek: _timesPerWeek),
  };

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Habit name is required');
      return;
    }
    if (name.length > 60) {
      setState(() => _nameError = 'Name must be 60 characters or less');
      return;
    }
    setState(() => _nameError = null);
    // A weekdays habit with zero days selected would be permanently
    // uncheckable — Habit.isScheduledOnWeekday returns false for every
    // day when WeekdaysConfig.weekdays is empty, and every check-in
    // surface (Home tile/grid, Habit Detail, the monthly grid) gates on
    // exactly that.
    if (_frequencyType == FrequencyType.weekdays && _weekdays.isEmpty) {
      AppSnackBar.show(
        context,
        'Pick at least one day',
        type: SnackBarType.error,
      );
      return;
    }
    if (widget.existing == null) {
      final activeCount =
          (await ref.read(habitRepositoryProvider).watchActiveHabits().first)
              .length;
      final isPremium = await ref.read(hasActiveEntitlementProvider.future);
      if (!isPremium && activeCount >= AppConfig.freeTierHabitLimit) {
        if (mounted) {
          await navigateToPaywall(context, ref);
        }
        return;
      }
    }
    setState(() => _isSaving = true);
    final repo = ref.read(habitRepositoryProvider);
    final reminder = _reminderTime == null
        ? null
        : '${_reminderTime!.hour.toString().padLeft(2, '0')}:'
              '${_reminderTime!.minute.toString().padLeft(2, '0')}';
    final existing = widget.existing;
    final frequencyWillChange =
        existing != null && existing.frequencyType != _frequencyType;
    String habitId;
    if (existing == null) {
      final description = _descriptionController.text.trim();
      final created = await repo.createHabit(
        name: name,
        emoji: _emoji,
        colorHex: colorToHex(_color),
        frequencyType: _frequencyType,
        frequencyConfig: _frequencyConfig,
        reminderTime: reminder,
        description: description.isEmpty ? null : description,
        categoryId: _categoryId,
        targetCount: _isQuantityHabit ? _targetCount : null,
        targetUnit: _isQuantityHabit
            ? (_targetUnitController.text.trim().isEmpty
                  ? 'times'
                  : _targetUnitController.text.trim())
            : null,
        isQuitHabit: _isQuitHabit,
      );
      habitId = created.id;
      final habitNumber = (await repo.watchActiveHabits().first).length;
      await ref
          .read(analyticsServiceProvider)
          .logHabitCreated(habitNumber: habitNumber);
    } else {
      final description = _descriptionController.text.trim();
      await repo.updateHabit(
        id: existing.id,
        name: name,
        emoji: _emoji,
        colorHex: colorToHex(_color),
        frequencyType: _frequencyType,
        frequencyConfig: _frequencyConfig,
        reminderTime: reminder,
        description: description.isEmpty ? null : description,
        categoryId: _categoryId,
        clearCategoryId: _categoryId == null,
        targetCount: _isQuantityHabit ? _targetCount : null,
        clearTargetCount: !_isQuantityHabit,
        targetUnit: _isQuantityHabit
            ? (_targetUnitController.text.trim().isEmpty
                  ? 'times'
                  : _targetUnitController.text.trim())
            : null,
        clearTargetUnit: !_isQuantityHabit,
        isQuitHabit: _isQuitHabit,
      );
      habitId = existing.id;
    }
    final notifications = ref.read(notificationServiceProvider);
    if (_reminderTime == null) {
      await notifications.cancelReminder(habitId);
    } else {
      // Fetch the latest habit to get the current streak for the notification body.
      final latestHabit = await ref
          .read(habitRepositoryProvider)
          .getHabitById(habitId);
      await notifications.scheduleDailyReminder(
        habitId: habitId,
        habitName: name,
        habitEmoji: _emoji,
        currentStreak: latestHabit?.currentStreak ?? 0,
        time: _reminderTime!,
        scheduledWeekdays: _frequencyType == FrequencyType.weekdays
            ? _weekdays.toList()
            : null,
      );
    }
    if (!mounted) return;
    if (widget.isFirstHabit) {
      AppSnackBar.show(
        context,
        AppCopy.firstHabitCreated,
        type: SnackBarType.success,
      );
    } else if (frequencyWillChange) {
      AppSnackBar.show(
        context,
        AppCopy.frequencyChangedNotice,
        type: SnackBarType.info,
      );
    }
    Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await _showConfirmDialog(
      title: AppCopy.deleteHabitConfirmTitle,
      body: AppCopy.deleteHabitConfirmBody,
      confirmLabel: 'Delete',
      isDanger: true,
    );
    if (confirmed != true) return;
    await ref.read(habitRepositoryProvider).deleteHabit(widget.existing!.id);
    // Cancels both the daily reminder AND the scheduled streak-at-risk
    // alert — cancelReminder alone left a deleted habit's 9pm risk alert
    // firing anyway if it had already been scheduled for tonight.
    await ref
        .read(notificationServiceProvider)
        .cancelAllForHabit(widget.existing!.id);
    // popUntil home — the stack is Home → HabitDetail → EditHabit,
    // so a single pop() would land on HabitDetail (which now shows a
    // deleted habit). Pop all the way back to the root instead.
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _archive() async {
    final confirmed = await _showConfirmDialog(
      title: 'Archive habit?',
      body:
          'This habit will be hidden from your list. You can restore it from the archived habits screen.',
      confirmLabel: 'Archive',
      isDanger: false,
    );
    if (confirmed != true) return;
    await ref.read(habitRepositoryProvider).archiveHabit(widget.existing!.id);
    // See the matching comment in _confirmDelete() — an archived habit
    // must not still fire its streak-at-risk alert tonight.
    await ref
        .read(notificationServiceProvider)
        .cancelAllForHabit(widget.existing!.id);
    // Same as delete: pop all the way to home so the user doesn't land
    // on a HabitDetail screen for a habit that's now archived.
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String body,
    required String confirmLabel,
    required bool isDanger,
  }) {
    return showFlatConfirmDialog(
      context: context,
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      isDanger: isDanger,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surface : AppColors.surfaceLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final bgColor = isDark ? AppColors.background : AppColors.backgroundLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;

    final title = widget.isFirstHabit
        ? AppCopy.firstHabitHeadline
        : (_isEditing
              ? 'Edit habit'
              : widget.prefillName != null
              ? 'New habit from quick start'
              : 'New habit');

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: textPrimary,
          ),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: isDark ? AppColors.border : AppColors.borderLight,
          ),
        ),
        actions: [
          if (_isEditing)
            PopupMenuButton<String>(
              color: surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (value) {
                if (value == 'archive') _archive();
                if (value == 'delete') _confirmDelete();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'archive',
                  child: Row(
                    children: [
                      Icon(Icons.archive_outlined, size: 18, color: textMuted),
                      const SizedBox(width: 10),
                      Text('Archive', style: TextStyle(color: textPrimary)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: AppColors.danger,
                      ),
                      SizedBox(width: 10),
                      Text('Delete', style: TextStyle(color: AppColors.danger)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ── Hero: name + icon, tinted by the chosen color ─────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroCard(
                emoji: _emoji,
                color: _color,
                nameController: _nameController,
                hasError: _nameError != null,
                isDark: isDark,
                onTapEmoji: _openEmojiPicker,
                onNameChanged: () {
                  if (_nameError != null) setState(() => _nameError = null);
                },
              ),
              if (_nameError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 13,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _nameError!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ).animate().fadeIn(delay: 40.ms).slideY(begin: 0.1),

          const SizedBox(height: 22),

          // ── Color ──────────────────────────────────────────────────────────
          _FormSectionHeader(
            title: 'Color',
            accent: _color,
            textPrimary: textPrimary,
            textMuted: textMuted,
          ),
          const SizedBox(height: 8),
          EditSectionCard(
            child: _ColorSwatchRow(
              selected: _color,
              onSelect: (c) => setState(() => _color = c),
              onCustomTap: _openColorPicker,
              isDark: isDark,
            ),
          ).animate().fadeIn(delay: 90.ms).slideY(begin: 0.1),

          const SizedBox(height: 22),

          // ── Frequency ────────────────────────────────────────────────────
          _FormSectionHeader(
            title: 'Frequency',
            accent: _color,
            textPrimary: textPrimary,
            textMuted: textMuted,
          ),
          const SizedBox(height: 8),
          EditSectionCard(
            child: Column(
              children: [
                SegmentedButton<FrequencyType>(
                  segments: const [
                    ButtonSegment(
                      value: FrequencyType.daily,
                      label: Text('Daily'),
                    ),
                    ButtonSegment(
                      value: FrequencyType.weekdays,
                      label: Text('Weekdays'),
                    ),
                    ButtonSegment(
                      value: FrequencyType.xPerWeek,
                      label: Text('X/week'),
                    ),
                  ],
                  selected: {_frequencyType},
                  onSelectionChanged: (selection) =>
                      setState(() => _frequencyType = selection.first),
                ),
                if (_frequencyType == FrequencyType.weekdays) ...[
                  const SizedBox(height: 16),
                  _buildWeekdayPicker(),
                ],
                if (_frequencyType == FrequencyType.xPerWeek) ...[
                  const SizedBox(height: 16),
                  _buildTimesPerWeekPicker(textPrimary),
                ],
              ],
            ),
          ).animate().fadeIn(delay: 140.ms).slideY(begin: 0.1),

          const SizedBox(height: 22),

          // ── Details: category + quantity + quit-habit mode ──────────────
          _FormSectionHeader(
            title: 'Details',
            subtitle: 'Category & type',
            accent: _color,
            textPrimary: textPrimary,
            textMuted: textMuted,
          ),
          const SizedBox(height: 8),
          EditSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CATEGORY',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                _CategoryPicker(
                  selectedId: _categoryId,
                  accentColor: _color,
                  onSelected: (id) => setState(() => _categoryId = id),
                ),
                const Divider(height: 32),
                Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _isQuantityHabit,
                    activeThumbColor: _color,
                    title: Text(
                      'Track a number',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'e.g. "8 glasses" instead of a plain yes/no',
                      style: TextStyle(color: textMuted, fontSize: 12),
                    ),
                    onChanged: (v) => setState(() => _isQuantityHabit = v),
                  ),
                ),
                if (_isQuantityHabit) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Target: $_targetCount',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      EditCounterButton(
                        icon: Icons.remove_rounded,
                        onPressed: _targetCount > 1
                            ? () => setState(() => _targetCount--)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      EditCounterButton(
                        icon: Icons.add_rounded,
                        onPressed: () => setState(() => _targetCount++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _targetUnitController,
                    style: TextStyle(color: textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Unit - e.g. glasses, pages, minutes',
                      hintStyle: TextStyle(
                        color: textMuted.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? AppColors.surfaceElevated
                          : AppColors.surfaceElevatedLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
                const Divider(height: 24),
                Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _isQuitHabit,
                    activeThumbColor: _color,
                    title: Text(
                      'This is a habit I\'m quitting',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'Framed as "days clean" instead of a streak',
                      style: TextStyle(color: textMuted, fontSize: 12),
                    ),
                    onChanged: (v) => setState(() => _isQuitHabit = v),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 190.ms).slideY(begin: 0.1),

          const SizedBox(height: 22),

          // ── Reminder ─────────────────────────────────────────────────────
          _FormSectionHeader(
            title: 'Reminder',
            accent: _color,
            textPrimary: textPrimary,
            textMuted: textMuted,
          ),
          const SizedBox(height: 8),
          EditSectionCard(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _reminderTime != null
                        ? _color.withValues(alpha: 0.15)
                        : bgColor,
                  ),
                  child: Icon(
                    Icons.notifications_outlined,
                    color: _reminderTime != null ? _color : textMuted,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _reminderTime?.format(context) ?? 'No reminder set',
                    style: TextStyle(
                      color: _reminderTime != null ? textPrimary : textMuted,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (_reminderTime != null)
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textMuted, size: 18),
                    tooltip: 'Clear reminder',
                    onPressed: () => setState(() => _reminderTime = null),
                  ),
                TextButton(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime:
                          _reminderTime ?? const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (picked != null) {
                      setState(() => _reminderTime = picked);
                    }
                  },
                  child: Text(
                    _reminderTime != null ? 'Change' : 'Set',
                    style: TextStyle(
                      color: _color,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 240.ms).slideY(begin: 0.1),

          const SizedBox(height: 22),

          // ── Description ──────────────────────────────────────────────────
          _FormSectionHeader(
            title: 'Description',
            subtitle: 'Optional',
            accent: _color,
            textPrimary: textPrimary,
            textMuted: textMuted,
          ),
          const SizedBox(height: 8),
          EditSectionCard(
            child: TextField(
              controller: _descriptionController,
              maxLength: 200,
              maxLines: 6,
              minLines: 3,
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w400,
                fontSize: 14,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText:
                    'What do you want to track? e.g. Run at least 3 km every morning…',
                hintStyle: TextStyle(
                  color: textMuted.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                counterText: '',
              ),
            ),
          ).animate().fadeIn(delay: 280.ms).slideY(begin: 0.1),
        ],
      ),
      // Docked to the bottom, same anchoring as the sign-in screen's
      // Google button — a fixed bar with a top border, not a floating
      // button hovering over the scroll content.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(top: BorderSide(color: border)),
          ),
          child: EditSaveButton(
            isEditing: _isEditing,
            isSaving: _isSaving,
            accentColor: _color,
            onPressed: _save,
          ),
        ),
      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
    );
  }

  Widget _buildWeekdayPicker() {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < 7; i++)
          EditDayChip(
            label: labels[i],
            selected: _weekdays.contains(i + 1),
            accentColor: _color,
            onTap: () => setState(() {
              final iso = i + 1;
              _weekdays.contains(iso)
                  ? _weekdays.remove(iso)
                  : _weekdays.add(iso);
            }),
          ),
      ],
    );
  }

  Widget _buildTimesPerWeekPicker(Color textPrimary) {
    return Row(
      children: [
        Text(
          '$_timesPerWeek× per week',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        EditCounterButton(
          icon: Icons.remove_rounded,
          onPressed: _timesPerWeek > 1
              ? () => setState(() => _timesPerWeek--)
              : null,
        ),
        const SizedBox(width: 8),
        EditCounterButton(
          icon: Icons.add_rounded,
          onPressed: _timesPerWeek < 7
              ? () => setState(() => _timesPerWeek++)
              : null,
        ),
      ],
    );
  }
}

// ─── Hero card ────────────────────────────────────────────────────────────────
//
// The habit's name and icon, front and center — tinted by the chosen
// accent color so the whole screen reads as "building this specific
// habit" rather than a generic settings form. Tapping the emoji opens the
// icon picker sheet ([_EditHabitScreenState._openEmojiPicker]); color is
// chosen just below via [_ColorSwatchRow].
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.emoji,
    required this.color,
    required this.nameController,
    required this.hasError,
    required this.isDark,
    required this.onTapEmoji,
    required this.onNameChanged,
  });

  final String emoji;
  final Color color;
  final TextEditingController nameController;
  final bool hasError;
  final bool isDark;
  final VoidCallback onTapEmoji;
  final VoidCallback onNameChanged;

  @override
  Widget build(BuildContext context) {
    final base = isDark ? AppColors.surface : AppColors.surfaceLight;
    final tinted = Color.alphaBlend(
      color.withValues(alpha: isDark ? 0.16 : 0.10),
      base,
    );
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tinted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasError ? AppColors.danger : color.withValues(alpha: 0.3),
          width: hasError ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTapEmoji,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: isDark ? 0.22 : 0.16),
                    border: Border.all(
                      color: color.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 17,
                    height: 17,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(color: tinted, width: 1.5),
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      size: 9,
                      color: contrastForeground(color),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: nameController,
              maxLength: 60,
              onChanged: (_) => onNameChanged(),
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                letterSpacing: -0.1,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Name your habit',
                hintStyle: TextStyle(
                  color: textMuted.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                counterText: '',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Form section header ──────────────────────────────────────────────────────
//
// Same visual language as Analytics/Habit Detail's section headers — a
// colored bar + title — so this screen reads as part of the same app
// instead of inventing its own typographic system.
class _FormSectionHeader extends StatelessWidget {
  const _FormSectionHeader({
    required this.title,
    this.subtitle,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
  });

  final String title;
  final String? subtitle;
  final Color accent;
  final Color textPrimary;
  final Color textMuted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Container(
          width: 3,
          height: 13,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 6),
          Text(subtitle!, style: TextStyle(color: textMuted, fontSize: 11)),
        ],
      ],
    );
  }
}

// ─── Color swatch row ──────────────────────────────────────────────────────────
//
// The 16 presets as a compact inline strip (not a whole card of their
// own) plus one more swatch for "custom" — filled with the current color
// and a check when it's a custom pick, an outlined pipette otherwise —
// opening the full HSV picker on tap.
class _ColorSwatchRow extends StatelessWidget {
  const _ColorSwatchRow({
    required this.selected,
    required this.onSelect,
    required this.onCustomTap,
    required this.isDark,
  });

  final Color selected;
  final ValueChanged<Color> onSelect;
  final VoidCallback onCustomTap;
  final bool isDark;

  bool get _isPreset =>
      _presetColors.any((c) => c.toARGB32() == selected.toARGB32());

  @override
  Widget build(BuildContext context) {
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final surfaceElevated = isDark
        ? AppColors.surfaceElevated
        : AppColors.surfaceElevatedLight;
    final isCustom = !_isPreset;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._presetColors.map((c) {
          final isSelected = c.toARGB32() == selected.toARGB32();
          return GestureDetector(
            onTap: () => onSelect(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c,
                border: Border.all(
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      color: isDark ? Colors.black : Colors.white,
                      size: 12,
                    )
                  : null,
            ),
          );
        }),
        GestureDetector(
          onTap: onCustomTap,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCustom ? selected : surfaceElevated,
              border: Border.all(
                color: isCustom
                    ? (isDark ? Colors.white : Colors.black)
                    : border,
                width: isCustom ? 1.5 : 1,
              ),
            ),
            child: Icon(
              isCustom ? Icons.check_rounded : Icons.colorize_rounded,
              size: isCustom ? 12 : 11,
              color: isCustom ? contrastForeground(selected) : textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Category picker ────────────────────────────────────────────────────────
//
// Predefined categories + the user's own custom ones, with a "+ New" chip
// that opens a small creation sheet (name + emoji + color, reusing the
// same emoji list and color presets already built for habits themselves).
class _CategoryPicker extends ConsumerWidget {
  const _CategoryPicker({
    required this.selectedId,
    required this.accentColor,
    required this.onSelected,
  });

  final String? selectedId;
  final Color accentColor;
  final ValueChanged<String?> onSelected;

  Future<void> _createCategory(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    String emoji = '🔖';
    Color color = accentColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.surfaceLight;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New category',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: TextField(
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22),
                      decoration: const InputDecoration(labelText: 'Emoji'),
                      controller: TextEditingController(text: emoji),
                      onChanged: (v) => setSheetState(
                        () => emoji = v.isEmpty ? '🔖' : v.characters.first,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: nameController,
                      maxLength: 30,
                      style: TextStyle(color: textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetColors.map((c) {
                  final selected = c.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () => setSheetState(() => color = c),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c,
                        border: Border.all(
                          color: selected
                              ? (isDark ? Colors.white : Colors.black)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: nameController.text.trim().isEmpty
                      ? null
                      : () => Navigator.of(sheetContext).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Create category',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(sheetContext).padding.bottom),
            ],
          ),
        ),
      ),
    );

    if (created != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    final category = await ref
        .read(habitRepositoryProvider)
        .createCategory(name: name, emoji: emoji, colorHex: colorToHex(color));
    onSelected(category.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.textPrimary
        : AppColors.textPrimaryLight;
    final textMuted = isDark ? AppColors.textMuted : AppColors.textMutedLight;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in categories)
          GestureDetector(
            onTap: () =>
                onSelected(selectedId == category.id ? null : category.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: selectedId == category.id
                    ? colorFromHex(category.colorHex).withValues(alpha: 0.18)
                    : (isDark
                          ? AppColors.surfaceElevated
                          : AppColors.surfaceElevatedLight),
                border: Border.all(
                  color: selectedId == category.id
                      ? colorFromHex(category.colorHex)
                      : (isDark ? AppColors.border : AppColors.borderLight),
                  width: selectedId == category.id ? 1.5 : 1,
                ),
              ),
              child: Text(
                '${category.emoji} ${category.name}',
                style: TextStyle(
                  color: selectedId == category.id ? textPrimary : textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        GestureDetector(
          onTap: () => _createCategory(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.border : AppColors.borderLight,
                style: BorderStyle.solid,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 14, color: textMuted),
                const SizedBox(width: 3),
                Text(
                  'New',
                  style: TextStyle(
                    color: textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
