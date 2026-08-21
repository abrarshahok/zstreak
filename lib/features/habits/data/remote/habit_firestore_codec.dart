import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/frequency.dart';
import '../../domain/habit.dart';

/// Single source of truth for the Habit ↔ Firestore document mapping.
///
/// Before this existed, the same fields were hand-written independently in
/// [FirestoreHabitRepository]'s create/update/read and again in
/// `MigrationService`'s guest-to-Firestore transform — which is how a
/// migrated habit silently lost its `description` and `sortOrder` (neither
/// field was ever added to the migration path's hand-rolled map).
class HabitFirestoreCodec {
  HabitFirestoreCodec._();

  /// Fields shared by every write path — the part that's easy to let drift
  /// out of sync between call sites if it's hand-written more than once.
  static Map<String, dynamic> _sharedFields({
    required String name,
    required String emoji,
    required String colorHex,
    required FrequencyType frequencyType,
    required FrequencyConfig frequencyConfig,
    String? reminderTime,
    String? description,
  }) {
    return {
      'name': name,
      'emoji': emoji,
      'colorHex': colorHex,
      'frequencyType': frequencyType.toDbValue(),
      'frequencyConfig': frequencyConfig.toJson(),
      'reminderTime': reminderTime,
      'description': description,
    };
  }

  /// A brand-new habit doc — streaks start at zero, timestamps are now.
  static Map<String, dynamic> forCreate({
    required String name,
    required String emoji,
    required String colorHex,
    required FrequencyType frequencyType,
    required FrequencyConfig frequencyConfig,
    String? reminderTime,
    String? description,
    required DateTime createdAt,
  }) {
    return {
      ..._sharedFields(
        name: name,
        emoji: emoji,
        colorHex: colorHex,
        frequencyType: frequencyType,
        frequencyConfig: frequencyConfig,
        reminderTime: reminderTime,
        description: description,
      ),
      'currentStreak': 0,
      'longestStreak': 0,
      'createdAt': Timestamp.fromDate(createdAt),
      'archivedAt': null,
      'updatedAt': Timestamp.fromDate(createdAt),
      // Required — watchActiveHabits() orders by this field, and Firestore
      // silently excludes any document missing an orderBy field from the
      // query results. Without it, a newly created habit would write
      // successfully but never appear in the list. Matches Drift's column
      // default (0) for the same field, so new habits sort first until
      // explicitly reordered — same as a fresh guest-mode habit would.
      'sortOrder': 0,
    };
  }

  /// An edit to an existing habit — streaks/timestamps outside this map
  /// (currentStreak, archivedAt) are left untouched by the caller.
  static Map<String, dynamic> forUpdate({
    required String name,
    required String emoji,
    required String colorHex,
    required FrequencyType frequencyType,
    required FrequencyConfig frequencyConfig,
    String? reminderTime,
    String? description,
  }) {
    return {
      ..._sharedFields(
        name: name,
        emoji: emoji,
        colorHex: colorHex,
        frequencyType: frequencyType,
        frequencyConfig: frequencyConfig,
        reminderTime: reminderTime,
        description: description,
      ),
      'updatedAt': Timestamp.now(),
    };
  }

  /// A full document for a guest→Firestore migration, preserving the
  /// existing streaks/timestamps/archive/sort state rather than resetting
  /// them the way [forCreate] does for a genuinely new habit.
  static Map<String, dynamic> forMigration({
    required String name,
    required String emoji,
    required String colorHex,
    required FrequencyType frequencyType,
    required FrequencyConfig frequencyConfig,
    String? reminderTime,
    String? description,
    required int currentStreak,
    required int longestStreak,
    required DateTime createdAt,
    required DateTime? archivedAt,
    required int sortOrder,
  }) {
    return {
      ..._sharedFields(
        name: name,
        emoji: emoji,
        colorHex: colorHex,
        frequencyType: frequencyType,
        frequencyConfig: frequencyConfig,
        reminderTime: reminderTime,
        description: description,
      ),
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'createdAt': Timestamp.fromDate(createdAt),
      'archivedAt': archivedAt == null ? null : Timestamp.fromDate(archivedAt),
      'updatedAt': Timestamp.now(),
      'sortOrder': sortOrder,
    };
  }

  static Habit fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) =>
      fromMap(doc.id, doc.data()!);

  /// The actual field-mapping logic, split out from [fromDocument] so it's
  /// testable against a plain [Map] — no live Firestore document required.
  static Habit fromMap(String id, Map<String, dynamic> data) {
    final type = FrequencyType.fromDbValue(data['frequencyType'] as String);
    return Habit(
      id: id,
      name: data['name'] as String,
      emoji: data['emoji'] as String,
      colorHex: data['colorHex'] as String,
      frequencyType: type,
      frequencyConfig: FrequencyConfig.fromJson(
        type,
        Map<String, dynamic>.from(data['frequencyConfig'] as Map),
      ),
      reminderTime: data['reminderTime'] as String?,
      description: data['description'] as String?,
      currentStreak: data['currentStreak'] as int? ?? 0,
      longestStreak: data['longestStreak'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      archivedAt: (data['archivedAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      sortOrder: data['sortOrder'] as int? ?? 0,
    );
  }
}
