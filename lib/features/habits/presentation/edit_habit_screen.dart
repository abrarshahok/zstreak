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
import '../domain/habit_template.dart';
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

const List<Color> _presetColors = [
  Color(0xFFB57BFF), // violet — matches app accent
  Color(0xFF00F0FF),
  Color(0xFFC6FF00),
  Color(0xFFFF00E5),
  Color(0xFFFFB800),
  Color(0xFFFF4D4D),
  Color(0xFFF5F5F7),
  Color(0xFF00FF94),
  Color(0xFFFF6B00),
  Color(0xFF4DFFB4),
  Color(0xFFFF4DA6),
  Color(0xFF4D9FFF),
  Color(0xFFFFD700),
  Color(0xFF7FFF00),
  Color(0xFFFF69B4),
  Color(0xFF40E0D0),
];

class EditHabitScreen extends ConsumerStatefulWidget {
  const EditHabitScreen({
    super.key,
    this.existing,
    this.template,
    this.isFirstHabit = false,
  });
  final Habit? existing;

  /// When set, pre-fills the form with template values (new habit flow).
  /// Ignored when [existing] is non-null.
  final HabitTemplate? template;
  final bool isFirstHabit;

  @override
  ConsumerState<EditHabitScreen> createState() => _EditHabitScreenState();
}

class _EditHabitScreenState extends ConsumerState<EditHabitScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _emojiSearchController;
  late String _emoji;
  late Color _color;
  late FrequencyType _frequencyType;
  late Set<int> _weekdays;
  late int _timesPerWeek;
  TimeOfDay? _reminderTime;
  bool _isSaving = false;
  String _emojiFilter = '';
  String? _nameError;

  bool get _isEditing => widget.existing != null;

  List<String> get _filteredEmojis {
    if (_emojiFilter.isEmpty) return _emojiChoices;
    return _emojiChoices.where((e) => e.contains(_emojiFilter)).toList();
  }

  @override
  void initState() {
    super.initState();
    final habit = widget.existing;
    final tmpl = widget.template;
    // Priority: existing habit > template > defaults.
    _nameController = TextEditingController(
      text: habit?.name ?? tmpl?.name ?? '',
    );
    _descriptionController = TextEditingController(
      text: habit?.description ?? tmpl?.description ?? '',
    );
    _emojiSearchController = TextEditingController();
    _emoji = habit?.emoji ?? tmpl?.emoji ?? _emojiChoices.first;
    _color = habit != null
        ? colorFromHex(habit.colorHex)
        : tmpl != null
        ? colorFromHex(tmpl.colorHex)
        : AppColors.accent;
    _frequencyType =
        habit?.frequencyType ?? tmpl?.frequencyType ?? FrequencyType.daily;
    final config = habit?.frequencyConfig;
    if (config is WeekdaysConfig) {
      _weekdays = config.weekdays.toSet();
    } else if (tmpl?.weekdays != null) {
      _weekdays = tmpl!.weekdays!.toSet();
    } else {
      _weekdays = {1, 2, 3, 4, 5};
    }
    if (config is XPerWeekConfig) {
      _timesPerWeek = config.timesPerWeek;
    } else if (tmpl?.timesPerWeek != null) {
      _timesPerWeek = tmpl!.timesPerWeek!;
    } else {
      _timesPerWeek = 3;
    }
    final reminder = habit?.reminderTime;
    if (reminder != null) {
      final parts = reminder.split(':');
      _reminderTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _emojiSearchController.dispose();
    super.dispose();
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
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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

    final title = widget.isFirstHabit
        ? AppCopy.firstHabitHeadline
        : (_isEditing
              ? 'Edit habit'
              : widget.template != null
              ? 'New habit from template'
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
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          120 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          // Name
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EditSectionCard(
                label: 'Habit name',
                hasError: _nameError != null,
                child: TextField(
                  controller: _nameController,
                  maxLength: 60,
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  onChanged: (_) {
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                  decoration: InputDecoration(
                    hintText: 'e.g. Morning run, Read 20 pages…',
                    hintStyle: TextStyle(
                      color: textMuted.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w400,
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    counterText: '',
                  ),
                ),
              ),
              if (_nameError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
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
          ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.1),

          const SizedBox(height: 20),

          // Description
          EditSectionCard(
            label: 'Description (optional)',
            child: TextField(
              controller: _descriptionController,
              maxLength: 200,
              maxLines: 8,
              minLines: 5,
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
          ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.1),

          const SizedBox(height: 12),

          // Emoji picker
          EditSectionCard(
            label: 'Icon',
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: _color.withValues(alpha: 0.12),
                        border: Border.all(
                          color: _color.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _emoji,
                          style: const TextStyle(fontSize: 25),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _emojiSearchController,
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
                          fillColor: isDark
                              ? AppColors.surfaceElevated
                              : AppColors.surfaceElevatedLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.border
                                  : AppColors.borderLight,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.border
                                  : AppColors.borderLight,
                            ),
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
                        onChanged: (v) => setState(() => _emojiFilter = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 220,
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                        ),
                    itemCount: _filteredEmojis.length,
                    itemBuilder: (context, i) {
                      final e = _filteredEmojis[i];
                      final selected = e == _emoji;
                      return GestureDetector(
                        onTap: () => setState(() => _emoji = e),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: selected
                                ? _color.withValues(alpha: 0.15)
                                : isDark
                                ? AppColors.surfaceElevated
                                : AppColors.surfaceElevatedLight,
                            border: Border.all(
                              color: selected
                                  ? _color
                                  : isDark
                                  ? AppColors.border
                                  : AppColors.borderLight,
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
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

          const SizedBox(height: 12),

          // Frequency
          EditSectionCard(
            label: 'Frequency',
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
          ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),

          const SizedBox(height: 12),

          // Reminder
          EditSectionCard(
            label: 'Reminder',
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
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

          const SizedBox(height: 12),

          // Color
          EditSectionCard(
            label: 'Color',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _presetColors.map((c) {
                    final selected = c.toARGB32() == _color.toARGB32();
                    return GestureDetector(
                      onTap: () => setState(() => _color = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 36,
                        height: 36,
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
                        child: selected
                            ? Icon(
                                Icons.check_rounded,
                                color: isDark ? Colors.black : Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _openColorPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _color.withValues(alpha: 0.08),
                      border: Border.all(
                        color: _color.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Custom color  →  #${colorToHex(_color).toUpperCase()}',
                          style: TextStyle(
                            color: _color,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),
        ],
      ),
      floatingActionButton: EditSaveFab(
        isEditing: _isEditing,
        isSaving: _isSaving,
        accentColor: _color,
        onPressed: _save,
      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
