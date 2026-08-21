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

  bool get isArchived => archivedAt != null;

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
    );
  }
}
