import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zstreak/features/habits/data/remote/habit_firestore_codec.dart';
import 'package:zstreak/features/habits/domain/frequency.dart';

void main() {
  group('HabitFirestoreCodec.forCreate', () {
    test('starts streaks at zero and mirrors createdAt into updatedAt', () {
      final now = DateTime(2026, 3, 10, 9, 30);
      final map = HabitFirestoreCodec.forCreate(
        name: 'Morning run',
        emoji: '🏃',
        colorHex: '#B57BFF',
        frequencyType: FrequencyType.daily,
        frequencyConfig: const DailyConfig(),
        reminderTime: '07:00',
        description: 'Run 3km',
        createdAt: now,
      );

      expect(map['name'], 'Morning run');
      expect(map['frequencyType'], 'daily');
      expect(map['description'], 'Run 3km');
      expect(map['currentStreak'], 0);
      expect(map['longestStreak'], 0);
      expect(map['archivedAt'], isNull);
      expect((map['createdAt'] as Timestamp).toDate(), now);
      expect((map['updatedAt'] as Timestamp).toDate(), now);
    });

    test('always includes sortOrder — watchActiveHabits orders by it, and '
        'Firestore excludes documents missing an orderBy field entirely', () {
      final map = HabitFirestoreCodec.forCreate(
        name: 'Morning run',
        emoji: '🏃',
        colorHex: '#B57BFF',
        frequencyType: FrequencyType.daily,
        frequencyConfig: const DailyConfig(),
        reminderTime: null,
        description: null,
        createdAt: DateTime(2026, 3, 10),
      );

      expect(map.containsKey('sortOrder'), isTrue);
      expect(map['sortOrder'], 0);
    });
  });

  group('HabitFirestoreCodec.forUpdate', () {
    test('carries no streak or archive fields — those are the caller\'s job', () {
      final map = HabitFirestoreCodec.forUpdate(
        name: 'Read 20 pages',
        emoji: '📚',
        colorHex: '#B57BFF',
        frequencyType: FrequencyType.xPerWeek,
        frequencyConfig: const XPerWeekConfig(timesPerWeek: 4),
        reminderTime: null,
        description: null,
      );

      expect(map.containsKey('currentStreak'), isFalse);
      expect(map.containsKey('archivedAt'), isFalse);
      expect(map['frequencyConfig'], {'timesPerWeek': 4, 'weekStartsOnMonday': true});
      expect(map.containsKey('updatedAt'), isTrue);
    });
  });

  group('HabitFirestoreCodec.forMigration', () {
    test('preserves description and sortOrder — the fields the old hand-rolled map dropped', () {
      final createdAt = DateTime(2025, 1, 1);
      final map = HabitFirestoreCodec.forMigration(
        name: 'Journal',
        emoji: '✍️',
        colorHex: '#FF4D4D',
        frequencyType: FrequencyType.daily,
        frequencyConfig: const DailyConfig(),
        reminderTime: null,
        description: 'Write one page a day',
        currentStreak: 45,
        longestStreak: 60,
        createdAt: createdAt,
        archivedAt: null,
        sortOrder: 3,
      );

      expect(map['description'], 'Write one page a day');
      expect(map['sortOrder'], 3);
      expect(map['currentStreak'], 45);
      expect(map['longestStreak'], 60);
      expect(map['archivedAt'], isNull);
    });

    test('encodes a non-null archivedAt as a Timestamp', () {
      final archivedAt = DateTime(2026, 2, 1);
      final map = HabitFirestoreCodec.forMigration(
        name: 'Old habit',
        emoji: '📦',
        colorHex: '#888888',
        frequencyType: FrequencyType.daily,
        frequencyConfig: const DailyConfig(),
        reminderTime: null,
        description: null,
        currentStreak: 0,
        longestStreak: 10,
        createdAt: DateTime(2025, 1, 1),
        archivedAt: archivedAt,
        sortOrder: 0,
      );

      expect((map['archivedAt'] as Timestamp).toDate(), archivedAt);
    });
  });

  group('HabitFirestoreCodec.fromMap', () {
    test('round-trips a create map back into an equivalent Habit', () {
      final now = DateTime(2026, 3, 10, 9, 30);
      final created = HabitFirestoreCodec.forCreate(
        name: 'Meditate',
        emoji: '🧘',
        colorHex: '#B14EFF',
        frequencyType: FrequencyType.weekdays,
        frequencyConfig: const WeekdaysConfig(weekdays: [1, 2, 3, 4, 5]),
        reminderTime: '06:30',
        description: 'Ten minutes',
        createdAt: now,
      );

      final habit = HabitFirestoreCodec.fromMap('habit-1', created);

      expect(habit.id, 'habit-1');
      expect(habit.name, 'Meditate');
      expect(habit.frequencyType, FrequencyType.weekdays);
      expect((habit.frequencyConfig as WeekdaysConfig).weekdays, [1, 2, 3, 4, 5]);
      expect(habit.reminderTime, '06:30');
      expect(habit.description, 'Ten minutes');
      expect(habit.currentStreak, 0);
      expect(habit.createdAt, now);
      expect(habit.archivedAt, isNull);
    });

    test('defaults currentStreak/longestStreak/sortOrder when absent from the map', () {
      final habit = HabitFirestoreCodec.fromMap('habit-2', {
        'name': 'Legacy habit',
        'emoji': '🕰️',
        'colorHex': '#CCCCCC',
        'frequencyType': 'daily',
        'frequencyConfig': <String, dynamic>{},
        'reminderTime': null,
        'description': null,
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        'archivedAt': null,
        'updatedAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        // currentStreak / longestStreak / sortOrder deliberately omitted.
      });

      expect(habit.currentStreak, 0);
      expect(habit.longestStreak, 0);
      expect(habit.sortOrder, 0);
    });
  });
}
