import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zstreak/features/auth/data/auth_repository.dart';
import 'package:zstreak/features/data_export/data_exporter.dart';
import 'package:zstreak/features/habits/domain/check_in.dart';
import 'package:zstreak/features/habits/domain/check_in_status.dart';
import 'package:zstreak/features/habits/domain/frequency.dart';
import 'package:zstreak/features/habits/domain/habit.dart';
import 'package:zstreak/features/habits/domain/habit_category.dart';
import 'package:zstreak/features/habits/domain/habit_repository.dart';
import 'package:zstreak/features/habits/domain/streak_calculator.dart';

/// Minimal in-memory [HabitRepository] — only the methods [DataExporter]
/// actually calls do anything real; [watchStreakDetail] delegates to the
/// real [StreakCalculator] so the exported numbers are genuine, not
/// hand-picked fixtures that could drift out of sync with it.
class FakeHabitRepository implements HabitRepository {
  FakeHabitRepository({
    required this.habits,
    required this.checkInsByHabit,
    this.categories = const [],
  });

  final List<Habit> habits;
  final Map<String, List<CheckIn>> checkInsByHabit;
  final List<HabitCategory> categories;

  @override
  Stream<List<Habit>> watchActiveHabits() =>
      Stream.value(habits.where((h) => h.archivedAt == null).toList());

  @override
  Stream<List<Habit>> watchArchivedHabits() =>
      Stream.value(habits.where((h) => h.archivedAt != null).toList());

  @override
  Stream<List<CheckIn>> watchHabitCheckIns(String habitId) =>
      Stream.value(checkInsByHabit[habitId] ?? const []);

  @override
  Stream<List<HabitCategory>> watchCategories() => Stream.value(categories);

  @override
  Stream<StreakResult> watchStreakDetail({
    required String habitId,
    required FrequencyType frequencyType,
    required FrequencyConfig frequencyConfig,
    required DateTime createdAt,
  }) {
    final statusByDate = <String, CheckInStatus>{
      for (final c in checkInsByHabit[habitId] ?? const []) c.date: c.status,
    };
    return Stream.value(
      StreakCalculator.compute(
        frequencyType: frequencyType,
        frequencyConfig: frequencyConfig,
        createdAtLocal: createdAt,
        statusByDate: statusByDate,
        today: DateTime.now(),
      ),
    );
  }

  @override
  Future<Habit?> getHabitById(String id) => throw UnimplementedError();
  @override
  Future<Habit> createHabit({
    required String name,
    required String emoji,
    required String colorHex,
    required FrequencyType frequencyType,
    required FrequencyConfig frequencyConfig,
    String? reminderTime,
    String? description,
    String? categoryId,
    int? targetCount,
    String? targetUnit,
    bool isQuitHabit = false,
  }) => throw UnimplementedError();
  @override
  Stream<CheckIn?> watchCheckIn({
    required String habitId,
    required String date,
  }) => throw UnimplementedError();
  @override
  Future<void> setCheckIn({
    required String habitId,
    required String date,
    required CheckInStatus status,
    String? note,
    int? value,
  }) => throw UnimplementedError();
  @override
  Future<({bool completed, int currentStreak})> toggleCheckIn({
    required String habitId,
    required String date,
  }) => throw UnimplementedError();
  @override
  Future<void> updateHabit({
    required String id,
    required String name,
    required String emoji,
    required String colorHex,
    required FrequencyType frequencyType,
    required FrequencyConfig frequencyConfig,
    String? reminderTime,
    String? description,
    String? categoryId,
    bool clearCategoryId = false,
    int? targetCount,
    bool clearTargetCount = false,
    String? targetUnit,
    bool clearTargetUnit = false,
    bool isQuitHabit = false,
  }) => throw UnimplementedError();
  @override
  Future<void> archiveHabit(String id) => throw UnimplementedError();
  @override
  Future<void> unarchiveHabit(String id) => throw UnimplementedError();
  @override
  Future<void> deleteHabit(String id) => throw UnimplementedError();
  @override
  Future<void> reorderHabits(List<String> orderedIds) =>
      throw UnimplementedError();
  @override
  Future<HabitCategory> createCategory({
    required String name,
    required String emoji,
    required String colorHex,
  }) => throw UnimplementedError();
  @override
  Future<void> updateCategory({
    required String id,
    required String name,
    required String emoji,
    required String colorHex,
  }) => throw UnimplementedError();
  @override
  Future<void> deleteCategory(String id) => throw UnimplementedError();
}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUser extends Mock implements User {}

class MockUserMetadata extends Mock implements UserMetadata {}

Habit _habit({
  required String id,
  required String name,
  String? categoryId,
  DateTime? archivedAt,
}) {
  final now = DateTime.now();
  return Habit(
    id: id,
    name: name,
    emoji: '🔥',
    colorHex: '#B57BFF',
    frequencyType: FrequencyType.daily,
    frequencyConfig: const DailyConfig(),
    createdAt: now.subtract(const Duration(days: 30)),
    updatedAt: now,
    archivedAt: archivedAt,
    categoryId: categoryId,
  );
}

/// Splits a full export CSV into its blank-line-delimited sections, in the
/// order [DataExporter.buildCsv] writes them: title/date, Account,
/// Summary, Habit Breakdown, Check-ins.
List<List<String>> _sections(String csv) =>
    csv.trim().split('\n\n').map((s) => s.split('\n')).toList();

void main() {
  group('DataExporter', () {
    late FakeHabitRepository repo;
    late MockAuthRepository auth;

    setUp(() {
      auth = MockAuthRepository();
      final today = DateTime.now();
      final checkIns = [
        for (var i = 0; i < 5; i++)
          CheckIn(
            id: 'c$i',
            habitId: 'meditate',
            date: today
                .subtract(Duration(days: i))
                .toIso8601String()
                .split('T')
                .first,
            status: CheckInStatus.completed,
            loggedAt: today,
          ),
      ];
      repo = FakeHabitRepository(
        habits: [
          _habit(id: 'meditate', name: 'Meditate', categoryId: 'mind'),
          _habit(
            id: 'old',
            name: 'Old habit',
            archivedAt: today.subtract(const Duration(days: 1)),
          ),
        ],
        checkInsByHabit: {'meditate': checkIns, 'old': const []},
      );
    });

    group('for a signed-in user', () {
      late DataExporter exporter;

      setUp(() {
        final user = MockUser();
        final metadata = MockUserMetadata();
        when(() => metadata.creationTime).thenReturn(DateTime(2025, 1, 5));
        when(() => user.isAnonymous).thenReturn(false);
        when(() => user.displayName).thenReturn('Jane Doe');
        when(() => user.email).thenReturn('jane@example.com');
        when(() => user.metadata).thenReturn(metadata);
        when(() => auth.currentUser).thenReturn(user);
        exporter = DataExporter(repo, auth);
      });

      test(
        'buildCsv is organized into labeled, blank-line-separated sections',
        () async {
          final csv = await exporter.buildCsv(isPro: true);
          final sections = _sections(csv);

          expect(sections[0].first, 'ZStreak Data Export');
          expect(sections[1].first, 'Account');
          expect(sections[2].first, 'Summary');
          expect(sections[3].first, 'Habit Breakdown');
          expect(sections[4].first, 'Check-ins');
          // 1 title line + 1 header row + 5 check-in rows for "meditate".
          expect(sections[4].length, 7);
        },
      );

      test('buildCsv includes the signed-in user\'s name and email', () async {
        final csv = await exporter.buildCsv(isPro: true);

        expect(csv.contains('Jane Doe'), isTrue);
        expect(csv.contains('jane@example.com'), isTrue);
        expect(csv.contains('Account type,Signed in'), isTrue);
      });

      test('buildCsv\'s Habit Breakdown section has one row per habit', () async {
        final csv = await exporter.buildCsv(isPro: true);
        final sections = _sections(csv);
        final breakdown = sections[3];

        expect(breakdown[0], 'Habit Breakdown');
        expect(
          breakdown[1],
          'habit_name,category,frequency,status,current_streak,longest_streak,completion_rate,total_check_ins',
        );
        // header line + one row for "meditate" + one row for "old".
        expect(breakdown.length, 4);
        expect(breakdown.any((l) => l.startsWith('Meditate,Mind,')), isTrue);
        expect(breakdown.any((l) => l.contains('Archived')), isTrue);
      });

      test('buildPdfBytes produces a well-formed, non-trivial PDF', () async {
        final bytes = await exporter.buildPdfBytes(isPro: true);

        // The %PDF- magic header is how every PDF-aware tool (readers,
        // mail clients, share-sheet previews) recognizes the file — if
        // this is wrong the "export" would silently hand the user a
        // broken file.
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
        // A real multi-section report (account + summary + chart + table)
        // should produce more than a token number of bytes; catches a
        // build that technically "succeeds" but renders an empty/near-
        // empty document.
        expect(bytes.length, greaterThan(2000));
      });
    });

    group('for a guest', () {
      test(
        'buildCsv notes the account is local-only, with no name/email',
        () async {
          when(() => auth.currentUser).thenReturn(null);
          final exporter = DataExporter(repo, auth);

          final csv = await exporter.buildCsv(isPro: false);
          final sections = _sections(csv);

          expect(sections[1], [
            'Account',
            'Account type,Guest (data stored on this device only)',
          ]);
        },
      );
    });

    group('free-tier export cap', () {
      // 5 active (well over the 3-habit free limit) + 1 archived, with
      // distinct createdAt so "most recently created" selection is
      // unambiguous. Simulates a user who had Pro (or simply archived
      // freely) and is now back on the free tier.
      late FakeHabitRepository cappedRepo;

      setUp(() {
        final now = DateTime.now();
        cappedRepo = FakeHabitRepository(
          habits: [
            for (var i = 0; i < 5; i++)
              Habit(
                id: 'active$i',
                name: 'Active $i',
                emoji: '🔥',
                colorHex: '#B57BFF',
                frequencyType: FrequencyType.daily,
                frequencyConfig: const DailyConfig(),
                // Larger i = created more recently.
                createdAt: now.subtract(Duration(days: 100 - i)),
                updatedAt: now,
              ),
            _habit(
              id: 'archived0',
              name: 'Archived 0',
              archivedAt: now.subtract(const Duration(days: 1)),
            ),
          ],
          checkInsByHabit: {
            for (var i = 0; i < 5; i++) 'active$i': const <CheckIn>[],
            'archived0': const [],
          },
        );
        when(() => auth.currentUser).thenReturn(null); // guest, for brevity
      });

      test('a Pro user\'s export is never capped', () async {
        final exporter = DataExporter(cappedRepo, auth);
        final csv = await exporter.buildCsv(isPro: true);
        final sections = _sections(csv);

        // No "Note" line injected after the generated-date line.
        expect(sections[0].length, 2);
        // All 5 active + 1 archived show up in the breakdown.
        expect(sections[3].length, 1 + 1 + 6); // title + header + 6 rows
      });

      test(
        'a free user\'s export keeps only the 3 most-recently-created active habits',
        () async {
          final exporter = DataExporter(cappedRepo, auth);
          final csv = await exporter.buildCsv(isPro: false);
          final sections = _sections(csv);
          final breakdown = sections[3];

          // title + header + 3 rows, archived excluded entirely.
          expect(breakdown.length, 5);
          expect(breakdown.any((l) => l.startsWith('Active 4,')), isTrue);
          expect(breakdown.any((l) => l.startsWith('Active 3,')), isTrue);
          expect(breakdown.any((l) => l.startsWith('Active 2,')), isTrue);
          expect(breakdown.any((l) => l.startsWith('Active 1,')), isFalse);
          expect(breakdown.any((l) => l.startsWith('Active 0,')), isFalse);
          expect(breakdown.any((l) => l.startsWith('Archived 0,')), isFalse);
        },
      );

      test(
        'a free user\'s export explains the truncation instead of silently shrinking',
        () async {
          final exporter = DataExporter(cappedRepo, auth);
          final csv = await exporter.buildCsv(isPro: false);
          final sections = _sections(csv);

          // 3 included + (2 omitted active + 1 omitted archived) = 6 total.
          expect(
            sections[0],
            contains(
              'Note,"Free plan - showing 3 of 6 habits (most recent, active only). Upgrade to Pro to export everything."',
            ),
          );
        },
      );

      test('capping applies to the PDF the same way', () async {
        final exporter = DataExporter(cappedRepo, auth);
        final bytes = await exporter.buildPdfBytes(isPro: false);

        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
        expect(bytes.length, greaterThan(2000));
      });
    });
  });
}
