#!/usr/bin/env python3
"""Writes the complete edit_habit_screen.dart with all helper classes."""

content = r'''import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart'
    hide colorFromHex, colorToHex;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/copy/app_copy.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/color_hex.dart';
import '../../analytics/analytics_service.dart';
import '../../monetization/application/entitlement_providers.dart';
import '../../monetization/presentation/paywall_screen.dart';
import '../../notifications/application/notification_providers.dart';
import '../application/habit_providers.dart';
import '../domain/frequency.dart';
import '../domain/habit.dart';

const List<String> _emojiChoices = [
  // Health & Fitness
  '\u{1F4AA}', '\u{1F3C3}', '\u{1F6B4}', '\u{1F3CB}', '\u{1F938}', '\u{1F9D8}', '\u{1F3CA}', '\u26F9', '\u{1F93E}', '\u{1F6B6}',
  '\u{1F94A}', '\u{1F3C7}', '\u{1F9D7}', '\u{1F93A}', '\u{1F3C4}', '\u{1F3BD}', '\u{1F9B5}',
  // Food & Drink
  '\u{1F957}', '\u{1F4A7}', '\u{1F34E}', '\u{1F966}', '\u{1F375}', '\u2615', '\u{1F964}', '\u{1F373}', '\u{1F951}', '\u{1FAD0}',
  '\u{1F347}', '\u{1F955}', '\u{1FAD6}', '\u{1F34B}', '\u{1F9C3}',
  // Mind & Learning
  '\u{1F4DA}', '\u270D', '\u{1F3AF}', '\u{1F9E0}', '\u{1F4D6}', '\u{1F58A}', '\u{1F4DD}', '\u{1F52C}', '\u{1F4A1}', '\u{1F393}',
  '\u{1F5E3}', '\u{1F9E9}', '\u{1F4D0}', '\u{1F52D}',
  // Sleep & Rest
  '\u{1F634}', '\u{1F319}', '\u{1F6CC}', '\u{1F4A4}', '\u{1F31F}',
  // Creativity & Hobbies
  '\u{1F3B8}', '\u{1F3B9}', '\u{1F3A8}', '\u270F', '\u{1F4F7}', '\u{1F3AC}', '\u{1F3AD}', '\u{1F3A4}', '\u{1F3BB}', '\u{1F941}',
  '\u{1F58C}', '\u{1F3AE}', '\u265F', '\u{1F3B2}', '\u{1FAB4}', '\u{1F331}',
  // Wellness & Lifestyle
  '\u{1F9F9}', '\u{1FAA5}', '\u{1F6AD}', '\u{1F377}', '\u{1F9F4}', '\u{1F6C1}', '\u{1FAA9}', '\u{1F33F}', '\u{1F56F}', '\u{1F48A}',
  // Finance & Productivity
  '\u{1F4B0}', '\u{1F4CA}', '\u{1F4C5}', '\u23F0', '\u2705', '\u{1F5D3}', '\u{1F4CC}', '\u{1F511}', '\u{1F4BC}', '\u{1F3E6}',
  // Social & Relationships
  '\u{1F4DE}', '\u{1F48C}', '\u{1F91D}', '\u{1F60A}', '\u{1FAC2}',
  // Nature & Outdoors
  '\u2600', '\u{1F333}', '\u{1F415}', '\u{1F30A}', '\u26F0', '\u{1F338}', '\u{1F98B}',
  // Symbols & Misc
  '\u2B50', '\u{1F525}', '\u26A1', '\u{1F3C6}', '\u{1F396}', '\u{1F680}', '\u{1F48E}', '\u{1F308}',
];

const List<Color> _presetColors = [
  Color(0xFF00F0FF),
  Color(0xFFC6FF00),
  Color(0xFFFF00E5),
  Color(0xFFFFB800),
  Color(0xFFB14EFF),
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
  const EditHabitScreen({super.key, this.existing, this.isFirstHabit = false});
  final Habit? existing;
  final bool isFirstHabit;

  @override
  ConsumerState<EditHabitScreen> createState() => _EditHabitScreenState();
}

class _EditHabitScreenState extends ConsumerState<EditHabitScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emojiSearchController;
  late String _emoji;
  late Color _color;
  late FrequencyType _frequencyType;
  late Set<int> _weekdays;
  late int _timesPerWeek;
  TimeOfDay? _reminderTime;
  bool _isSaving = false;
  String _emojiFilter = '';

  bool get _isEditing => widget.existing != null;

  List<String> get _filteredEmojis {
    if (_emojiFilter.isEmpty) return _emojiChoices;
    return _emojiChoices.where((e) => e.contains(_emojiFilter)).toList();
  }

  @override
  void initState() {
    super.initState();
    final habit = widget.existing;
    _nameController = TextEditingController(text: habit?.name ?? '');
    _emojiSearchController = TextEditingController();
    _emoji = habit?.emoji ?? _emojiChoices.first;
    _color = habit != null ? colorFromHex(habit.colorHex)! : AppColors.accent;
    _frequencyType = habit?.frequencyType ?? FrequencyType.daily;
    final config = habit?.frequencyConfig;
    _weekdays = config is WeekdaysConfig ? config.weekdays.toSet() : {1, 2, 3, 4, 5};
    _timesPerWeek = config is XPerWeekConfig ? config.timesPerWeek : 3;
    final reminder = habit?.reminderTime;
    if (reminder != null) {
      final parts = reminder.split(':');
      _reminderTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiSearchController.dispose();
    super.dispose();
  }

  Future<void> _openColorPicker() async {
    Color tempColor = _color;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 20),
              Text('Pick a color',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              ColorPicker(
                pickerColor: tempColor,
                onColorChanged: (c) => setModalState(() => tempColor = c),
                colorPickerWidth: MediaQuery.of(context).size.width - 40,
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
                  boxShadow: [BoxShadow(color: tempColor.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 4))],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () { setState(() => _color = tempColor); Navigator.of(context).pop(); },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tempColor, foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Apply color', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  FrequencyConfig get _frequencyConfig => switch (_frequencyType) {
    FrequencyType.daily => const DailyConfig(),
    FrequencyType.weekdays => WeekdaysConfig(weekdays: _weekdays.toList()..sort()),
    FrequencyType.xPerWeek => XPerWeekConfig(timesPerWeek: _timesPerWeek),
  };

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    if (widget.existing == null) {
      final activeCount = (await ref.read(habitRepositoryProvider).watchActiveHabits().first).length;
      final isPremium = await ref.read(hasActiveEntitlementProvider.future);
      if (!isPremium && activeCount >= AppConfig.freeTierHabitLimit) {
        if (mounted) await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
        return;
      }
    }
    setState(() => _isSaving = true);
    final repo = ref.read(habitRepositoryProvider);
    final reminder = _reminderTime == null
        ? null
        : '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}';
    final existing = widget.existing;
    final frequencyWillChange = existing != null && existing.frequencyType != _frequencyType;
    String habitId;
    if (existing == null) {
      final created = await repo.createHabit(
        name: name, emoji: _emoji, colorHex: colorToHex(_color),
        frequencyType: _frequencyType, frequencyConfig: _frequencyConfig, reminderTime: reminder,
      );
      habitId = created.id;
      final habitNumber = (await repo.watchActiveHabits().first).length;
      await ref.read(analyticsServiceProvider).logHabitCreated(habitNumber: habitNumber);
    } else {
      await repo.updateHabit(
        id: existing.id, name: name, emoji: _emoji, colorHex: colorToHex(_color),
        frequencyType: _frequencyType, frequencyConfig: _frequencyConfig, reminderTime: reminder,
      );
      habitId = existing.id;
    }
    final notifications = ref.read(notificationServiceProvider);
    if (_reminderTime == null) {
      await notifications.cancelReminder(habitId);
    } else {
      await notifications.scheduleDailyReminder(habitId: habitId, habitName: name, time: _reminderTime!);
    }
    if (!mounted) return;
    if (widget.isFirstHabit) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppCopy.firstHabitCreated)));
    } else if (frequencyWillChange) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppCopy.frequencyChangedNotice)));
    }
    Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(AppCopy.deleteHabitConfirmTitle),
        content: const Text(AppCopy.deleteHabitConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(habitRepositoryProvider).deleteHabit(widget.existing!.id);
    await ref.read(notificationServiceProvider).cancelReminder(widget.existing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _archive() async {
    await ref.read(habitRepositoryProvider).archiveHabit(widget.existing!.id);
    await ref.read(notificationServiceProvider).cancelReminder(widget.existing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isFirstHabit
        ? AppCopy.firstHabitHeadline
        : (_isEditing ? 'Edit habit' : 'New habit');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface.withValues(alpha: 0.8)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.textPrimary),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        actions: [
          if (_isEditing)
            PopupMenuButton<String>(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (value) { if (value == 'archive') _archive(); if (value == 'delete') _confirmDelete(); },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'archive', child: Row(children: [
                  Icon(Icons.archive_outlined, size: 18, color: AppColors.textMuted), SizedBox(width: 10), Text('Archive'),
                ])),
                const PopupMenuItem(value: 'delete', child: Row(children: [
                  Icon(Icons.delete_outline, size: 18, color: AppColors.danger), SizedBox(width: 10),
                  Text('Delete', style: TextStyle(color: AppColors.danger)),
                ])),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _SectionCard(
            child: TextField(
              controller: _nameController,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'What habit are you building?',
                hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.6), fontWeight: FontWeight.w400),
                filled: true, fillColor: Colors.transparent, border: InputBorder.none, contentPadding: EdgeInsets.zero,
              ),
            ),
          ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.1),
          const SizedBox(height: 12),
          _SectionCard(
            label: 'Icon  (${_emojiChoices.length}+ to choose from)',
            child: Column(children: [
              Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _color.withValues(alpha: 0.15),
                    border: Border.all(color: _color.withValues(alpha: 0.4), width: 2),
                  ),
                  child: Center(child: Text(_emoji, style: const TextStyle(fontSize: 26))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _emojiSearchController,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Paste emoji to filter\u2026',
                      hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 18),
                      filled: true, fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (v) => setState(() => _emojiFilter = v),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              SizedBox(
                height: 220,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6),
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
                          color: selected ? _color.withValues(alpha: 0.2) : AppColors.background,
                          border: Border.all(color: selected ? _color : Colors.transparent, width: 2),
                          boxShadow: selected ? [BoxShadow(color: _color.withValues(alpha: 0.3), blurRadius: 8)] : null,
                        ),
                        child: Center(child: Text(e, style: const TextStyle(fontSize: 20))),
                      ),
                    );
                  },
                ),
              ),
            ]),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
          const SizedBox(height: 12),
          _SectionCard(
            label: 'Frequency',
            child: Column(children: [
              SegmentedButton<FrequencyType>(
                segments: const [
                  ButtonSegment(value: FrequencyType.daily, label: Text('Daily')),
                  ButtonSegment(value: FrequencyType.weekdays, label: Text('Weekdays')),
                  ButtonSegment(value: FrequencyType.xPerWeek, label: Text('X/week')),
                ],
                selected: {_frequencyType},
                onSelectionChanged: (s) => setState(() => _frequencyType = s.first),
              ),
              if (_frequencyType == FrequencyType.weekdays) ...[const SizedBox(height: 16), _buildWeekdayPicker()],
              if (_frequencyType == FrequencyType.xPerWeek) ...[const SizedBox(height: 16), _buildTimesPerWeekPicker()],
            ]),
          ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),
          const SizedBox(height: 12),
          _SectionCard(
            label: 'Reminder',
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _reminderTime != null ? _color.withValues(alpha: 0.15) : AppColors.background,
                ),
                child: Icon(Icons.notifications_outlined,
                  color: _reminderTime != null ? _color : AppColors.textMuted, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(
                _reminderTime?.format(context) ?? 'No reminder set',
                style: TextStyle(
                  color: _reminderTime != null ? AppColors.textPrimary : AppColors.textMuted,
                  fontWeight: FontWeight.w500),
              )),
              if (_reminderTime != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                  onPressed: () => setState(() => _reminderTime = null),
                ),
              TextButton(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _reminderTime ?? const TimeOfDay(hour: 9, minute: 0),
                  );
                  if (picked != null) setState(() => _reminderTime = picked);
                },
                child: Text(_reminderTime != null ? 'Change' : 'Set',
                  style: TextStyle(color: _color, fontWeight: FontWeight.w600)),
              ),
            ]),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
          const SizedBox(height: 12),
          _SectionCard(
            label: 'Color',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                spacing: 10, runSpacing: 10,
                children: _presetColors.map((c) {
                  final selected = c.toARGB32() == _color.toARGB32();
                  return GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, color: c,
                        border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 3),
                        boxShadow: selected ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 12, spreadRadius: 2)] : null,
                      ),
                      child: selected ? const Icon(Icons.check_rounded, color: Colors.black, size: 18) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _openColorPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(colors: [_color.withValues(alpha: 0.2), AppColors.background]),
                    border: Border.all(color: _color.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, color: _color,
                        boxShadow: [BoxShadow(color: _color.withValues(alpha: 0.5), blurRadius: 8)],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('Custom color  \u2192  #${colorToHex(_color).toUpperCase()}',
                      style: TextStyle(color: _color, fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                ),
              ),
            ]),
          ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),
        ],
      ),
      floatingActionButton: _SaveFab(
        isEditing: _isEditing, isSaving: _isSaving, accentColor: _color, onPressed: _save,
      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildWeekdayPicker() {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: [
        for (var i = 0; i < 7; i++)
          _DayChip(
            label: labels[i],
            selected: _weekdays.contains(i + 1),
            accentColor: _color,
            onTap: () => setState(() {
              final iso = i + 1;
              _weekdays.contains(iso) ? _weekdays.remove(iso) : _weekdays.add(iso);
            }),
          ),
      ],
    );
  }

  Widget _buildTimesPerWeekPicker() {
    return Row(children: [
      Text('${_timesPerWeek}\u00D7 per week',
        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      const Spacer(),
      _CounterButton(icon: Icons.remove_rounded,
        onPressed: _timesPerWeek > 1 ? () => setState(() => _timesPerWeek--) : null),
      const SizedBox(width: 8),
      _CounterButton(icon: Icons.add_rounded,
        onPressed: _timesPerWeek < 7 ? () => setState(() => _timesPerWeek++) : null),
    ]);
  }
}

// ─── Section Card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.label});
  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.surface,
        border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (label != null) ...[
          Text(label!, style: const TextStyle(
            color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 12),
        ],
        child,
      ]),
    );
  }
}

// ─── Day Chip ─────────────────────────────────────────────────────────────────

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected ? accentColor : AppColors.background,
          border: Border.all(
            color: selected ? accentColor : Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? Colors.black : AppColors.textMuted,
          fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}

// ─── Counter Button ───────────────────────────────────────────────────────────

class _CounterButton extends StatelessWidget {
  const _CounterButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;