import 'frequency.dart';

/// Domain model shared by both backends (Drift for guests, Firestore for
/// signed-in users) — spec Section 5's "identical shape, different
/// backend" principle. Repositories map their storage row to/from this.
class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorHex,
    required this.frequencyType,
    required this.frequencyConfig,
    this.reminderTime,
    this.description,
    this.currentStreak = 0,
    this.longestStreak = 0,
    required this.createdAt,
    this.archivedAt,
    required this.updatedAt,
    this.sortOrder = 0,
    this.categoryId,
    this.targetCount,
    this.targetUnit,
    this.isQuitHabit = false,
  });

  final String id;
  final String name;
  final String emoji;
  final String colorHex;
  final FrequencyType frequencyType;
  final FrequencyConfig frequencyConfig;

  /// "HH:mm" local time, nullable — reminders are wired in Stage 8.
  final String? reminderTime;

  /// Optional free-text description of what the user plans to track.
  final String? description;

  final int currentStreak;
  final int longestStreak;
  final DateTime createdAt;
  final DateTime? archivedAt;
  final DateTime updatedAt;

  /// Feature 6 – Drag-to-reorder: position index; lower = higher in list.
  final int sortOrder;

  /// Either a [kPredefinedCategories] id or a persisted custom category's
  /// id. Null means uncategorized.
  final String? categoryId;

  /// Non-null makes this a quantity habit (e.g. "8 glasses") rather than a
  /// plain yes/no one — [targetUnit] is the free-text unit label. Both are
  /// null/non-null together.
  final int? targetCount;
  final String? targetUnit;

  bool get isQuantityHabit => targetCount != null;

  /// A habit being *quit* rather than built — changes copy/framing only
  /// (Habit Detail's "Days Clean" labeling); the underlying streak/status
  /// plumbing is identical to a normal habit.
  final bool isQuitHabit;

  bool get isArchived => archivedAt != null;

  /// Whether this habit is scheduled on the given ISO weekday (1=Mon..7=Sun).
  /// `daily` habits are scheduled every day, and `xPerWeek` habits have no
  /// per-day restriction (any day can count toward the weekly target) — only
  /// `weekdays` habits restrict check-ins to a specific set of days.
  bool isScheduledOnWeekday(int weekday) {
    return switch (frequencyType) {
      FrequencyType.daily || FrequencyType.xPerWeek => true,
      FrequencyType.weekdays =>
        (frequencyConfig as WeekdaysConfig).weekdays.contains(weekday),
    };
  }

  Habit copyWith({
    String? name,
    String? emoji,
    String? colorHex,
    FrequencyType? frequencyType,
    FrequencyConfig? frequencyConfig,
    String? reminderTime,
    String? description,
    bool clearDescription = false,
    int? currentStreak,
    int? longestStreak,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    required DateTime updatedAt,
    int? sortOrder,
    String? categoryId,
    bool clearCategoryId = false,
    int? targetCount,
    bool clearTargetCount = false,
    String? targetUnit,
    bool clearTargetUnit = false,
    bool? isQuitHabit,
  }) {
    return Habit(
      id: id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      colorHex: colorHex ?? this.colorHex,
      frequencyType: frequencyType ?? this.frequencyType,
      frequencyConfig: frequencyConfig ?? this.frequencyConfig,
      reminderTime: reminderTime ?? this.reminderTime,
      description: clearDescription ? null : (description ?? this.description),
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      createdAt: createdAt,
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
      updatedAt: updatedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      targetCount: clearTargetCount
          ? null
          : (targetCount ?? this.targetCount),
      targetUnit: clearTargetUnit ? null : (targetUnit ?? this.targetUnit),
      isQuitHabit: isQuitHabit ?? this.isQuitHabit,
    );
  }
}
