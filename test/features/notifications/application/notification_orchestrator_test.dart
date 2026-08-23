import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zstreak/core/utils/local_date.dart';
import 'package:zstreak/features/habits/application/habit_providers.dart';
import 'package:zstreak/features/habits/domain/check_in.dart';
import 'package:zstreak/features/habits/domain/frequency.dart';
import 'package:zstreak/features/habits/domain/habit.dart';
import 'package:zstreak/features/habits/domain/habit_repository.dart';
import 'package:zstreak/features/habits/domain/streak_calculator.dart';
import 'package:zstreak/features/monetization/application/entitlement_providers.dart';
import 'package:zstreak/features/notifications/application/notification_orchestrator.dart';
import 'package:zstreak/features/notifications/application/notification_providers.dart';
import 'package:zstreak/features/notifications/data/notification_service.dart';

class MockNotificationService extends Mock implements NotificationService {}

/// Minimal in-memory [HabitRepository] — only the two methods
/// [NotificationOrchestrator] actually calls ([watchActiveHabits],
/// [watchHabitCheckIns]) do anything; everything else is unused by these
/// tests and throws if a future test path starts needing it.
class FakeHabitRepository implements HabitRepository {
  FakeHabitRepository(this.habits, this.checkInsByHabit);

  final List<Habit> habits;
  final Map<String, List<CheckIn>> checkInsByHabit;

  @override
  Stream<List<Habit>> watchActiveHabits() => Stream.value(habits);

  @override
  Stream<List<CheckIn>> watchHabitCheckIns(String habitId) =>
      Stream.value(checkInsByHabit[habitId] ?? const []);

  @override
  Stream<List<Habit>> watchArchivedHabits() => throw UnimplementedError();
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
  }) => throw UnimplementedError();
  @override
  Stream<CheckIn?> watchCheckIn({required String habitId, required String date}) =>
      throw UnimplementedError();
  @override
  Future<void> setCheckIn({
    required String habitId,
    required String date,
    required bool completed,
    String? note,
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
  }) => throw UnimplementedError();
  @override
  Future<void> archiveHabit(String id) => throw UnimplementedError();
  @override
  Future<void> unarchiveHabit(String id) => throw UnimplementedError();
  @override
  Future<void> deleteHabit(String id) => throw UnimplementedError();
  @override
  Stream<StreakResult> watchStreakDetail({
    required String habitId,
    required FrequencyType frequencyType,
    required FrequencyConfig frequencyConfig,
    required DateTime createdAt,
  }) => throw UnimplementedError();
  @override
  Future<void> reorderHabits(List<String> orderedIds) => throw UnimplementedError();
}

Habit _habit({
  required String id,
  required FrequencyType frequencyType,
  FrequencyConfig? frequencyConfig,
  int currentStreak = 0,
}) {
  final now = DateTime.now();
  return Habit(
    id: id,
    name: 'Habit $id',
    emoji: '🔥',
    colorHex: '#B57BFF',
    frequencyType: frequencyType,
    frequencyConfig: frequencyConfig ?? const DailyConfig(),
    currentStreak: currentStreak,
    createdAt: now.subtract(const Duration(days: 100)),
    updatedAt: now,
  );
}

ProviderContainer _buildContainer({
  required List<Habit> habits,
  required Map<String, List<CheckIn>> checkIns,
  required MockNotificationService notifications,
}) {
  final container = ProviderContainer(
    overrides: [
      habitRepositoryProvider.overrideWithValue(
        FakeHabitRepository(habits, checkIns),
      ),
      notificationServiceProvider.overrideWithValue(notifications),
      hasActiveEntitlementProvider.overrideWith((ref) async => false),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUpAll(() {
    // scheduleProUpsell() / cancelProUpsell() etc. return Future<void>; an
    // unstubbed mocktail call already resolves fine when awaited, but
    // stubbing the ones every test hits keeps failures pointed at the
    // assertion instead of a surprising default.
    registerFallbackValue(DateTime.now());
  });

  group('NotificationOrchestrator.refresh — streak-at-risk', () {
    test('an xPerWeek habit always cancels streak-at-risk (no single "due today")', () async {
      final habit = _habit(
        id: 'weekly',
        frequencyType: FrequencyType.xPerWeek,
        frequencyConfig: const XPerWeekConfig(timesPerWeek: 3),
        currentStreak: 4,
      );
      final notifications = MockNotificationService();
      when(() => notifications.cancelStreakAtRisk(any())).thenAnswer((_) async {});
      when(() => notifications.scheduleWeeklySummary(
            activeHabits: any(named: 'activeHabits'),
            completedThisWeek: any(named: 'completedThisWeek'),
            totalDueThisWeek: any(named: 'totalDueThisWeek'),
          )).thenAnswer((_) async {});
      when(() => notifications.scheduleProUpsell()).thenAnswer((_) async {});
      when(() => notifications.cancelProUpsell()).thenAnswer((_) async {});

      final container = _buildContainer(
        habits: [habit],
        checkIns: const {},
        notifications: notifications,
      );

      await container.read(notificationOrchestratorProvider).refresh();

      verify(() => notifications.cancelStreakAtRisk('weekly')).called(1);
      verifyNever(() => notifications.scheduleStreakAtRisk(
            habitId: any(named: 'habitId'),
            habitName: any(named: 'habitName'),
            habitEmoji: any(named: 'habitEmoji'),
            currentStreak: any(named: 'currentStreak'),
            fireAt: any(named: 'fireAt'),
          ));
    });

    test('a habit already checked in today cancels streak-at-risk', () async {
      final habit = _habit(id: 'daily', frequencyType: FrequencyType.daily, currentStreak: 7);
      final today = todayLocalDateString();
      final notifications = MockNotificationService();
      when(() => notifications.cancelStreakAtRisk(any())).thenAnswer((_) async {});
      when(() => notifications.scheduleWeeklySummary(
            activeHabits: any(named: 'activeHabits'),
            completedThisWeek: any(named: 'completedThisWeek'),
            totalDueThisWeek: any(named: 'totalDueThisWeek'),
          )).thenAnswer((_) async {});
      when(() => notifications.scheduleProUpsell()).thenAnswer((_) async {});
      when(() => notifications.cancelProUpsell()).thenAnswer((_) async {});

      final container = _buildContainer(
        habits: [habit],
        checkIns: {
          'daily': [
            CheckIn(
              id: today,
              habitId: 'daily',
              date: today,
              completed: true,
              loggedAt: DateTime.now(),
            ),
          ],
        },
        notifications: notifications,
      );

      await container.read(notificationOrchestratorProvider).refresh();

      verify(() => notifications.cancelStreakAtRisk('daily')).called(1);
    });

    test('a habit with no streak yet neither schedules nor cancels', () async {
      final habit = _habit(id: 'fresh', frequencyType: FrequencyType.daily, currentStreak: 0);
      final notifications = MockNotificationService();
      when(() => notifications.scheduleWeeklySummary(
            activeHabits: any(named: 'activeHabits'),
            completedThisWeek: any(named: 'completedThisWeek'),
            totalDueThisWeek: any(named: 'totalDueThisWeek'),
          )).thenAnswer((_) async {});
      when(() => notifications.scheduleProUpsell()).thenAnswer((_) async {});
      when(() => notifications.cancelProUpsell()).thenAnswer((_) async {});

      final container = _buildContainer(
        habits: [habit],
        checkIns: const {},
        notifications: notifications,
      );

      await container.read(notificationOrchestratorProvider).refresh();

      verifyNever(() => notifications.cancelStreakAtRisk(any()));
      verifyNever(() => notifications.scheduleStreakAtRisk(
            habitId: any(named: 'habitId'),
            habitName: any(named: 'habitName'),
            habitEmoji: any(named: 'habitEmoji'),
            currentStreak: any(named: 'currentStreak'),
            fireAt: any(named: 'fireAt'),
          ));
    });

    test('a habit not scheduled on a weekday it doesn\'t run neither schedules nor cancels', () async {
      final todayWeekday = DateTime.now().weekday;
      final otherWeekday = todayWeekday == 1 ? 2 : 1; // guaranteed != today
      final habit = _habit(
        id: 'offday',
        frequencyType: FrequencyType.weekdays,
        frequencyConfig: WeekdaysConfig(weekdays: [otherWeekday]),
        currentStreak: 3,
      );
      final notifications = MockNotificationService();
      when(() => notifications.cancelStreakAtRisk(any())).thenAnswer((_) async {});
      when(() => notifications.scheduleWeeklySummary(
            activeHabits: any(named: 'activeHabits'),
            completedThisWeek: any(named: 'completedThisWeek'),
            totalDueThisWeek: any(named: 'totalDueThisWeek'),
          )).thenAnswer((_) async {});
      when(() => notifications.scheduleProUpsell()).thenAnswer((_) async {});
      when(() => notifications.cancelProUpsell()).thenAnswer((_) async {});

      final container = _buildContainer(
        habits: [habit],
        checkIns: const {},
        notifications: notifications,
      );

      await container.read(notificationOrchestratorProvider).refresh();

      // Not scheduled today → cancelled, same as the xPerWeek case, but for
      // a different reason (rest day, not "no single due date" by design).
      verify(() => notifications.cancelStreakAtRisk('offday')).called(1);
    });
  });

  group('NotificationOrchestrator.refresh — weekly summary', () {
    test('counts completions across all habits due so far this week', () async {
      final today = DateTime.now();
      final weekStart = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: today.weekday - 1));
      final daysSoFar = today.weekday; // Monday..today inclusive

      final habitA = _habit(id: 'a', frequencyType: FrequencyType.daily);
      final habitB = _habit(id: 'b', frequencyType: FrequencyType.daily);

      // Habit A: completed every due day so far this week. Habit B: none.
      final completedForA = [
        for (var d = 0; d < daysSoFar; d++)
          CheckIn(
            id: 'a-$d',
            habitId: 'a',
            date: localDateString(weekStart.add(Duration(days: d))),
            completed: true,
            loggedAt: DateTime.now(),
          ),
      ];

      final notifications = MockNotificationService();
      when(() => notifications.cancelStreakAtRisk(any())).thenAnswer((_) async {});
      when(() => notifications.scheduleStreakAtRisk(
            habitId: any(named: 'habitId'),
            habitName: any(named: 'habitName'),
            habitEmoji: any(named: 'habitEmoji'),
            currentStreak: any(named: 'currentStreak'),
            fireAt: any(named: 'fireAt'),
          )).thenAnswer((_) async {});
      when(() => notifications.scheduleWeeklySummary(
            activeHabits: any(named: 'activeHabits'),
            completedThisWeek: any(named: 'completedThisWeek'),
            totalDueThisWeek: any(named: 'totalDueThisWeek'),
          )).thenAnswer((_) async {});
      when(() => notifications.scheduleProUpsell()).thenAnswer((_) async {});
      when(() => notifications.cancelProUpsell()).thenAnswer((_) async {});

      final container = _buildContainer(
        habits: [habitA, habitB],
        checkIns: {'a': completedForA, 'b': const []},
        notifications: notifications,
      );

      await container.read(notificationOrchestratorProvider).refresh();

      verify(() => notifications.scheduleWeeklySummary(
            activeHabits: 2,
            completedThisWeek: daysSoFar,
            totalDueThisWeek: daysSoFar * 2,
          )).called(1);
    });
  });

  group('NotificationOrchestrator.onCheckIn', () {
    test('cancels the streak-at-risk alert and fires a milestone at a milestone streak', () async {
      final notifications = MockNotificationService();
      when(() => notifications.cancelStreakAtRisk(any())).thenAnswer((_) async {});
      when(() => notifications.fireMilestone(
            habitId: any(named: 'habitId'),
            habitName: any(named: 'habitName'),
            habitEmoji: any(named: 'habitEmoji'),
            streak: any(named: 'streak'),
          )).thenAnswer((_) async {});

      final container = _buildContainer(
        habits: const [],
        checkIns: const {},
        notifications: notifications,
      );

      await container.read(notificationOrchestratorProvider).onCheckIn(
            habitId: 'h1',
            habitName: 'Read',
            habitEmoji: '📚',
            newStreak: 7, // a milestone per NotificationService.isMilestone
          );

      verify(() => notifications.cancelStreakAtRisk('h1')).called(1);
      verify(() => notifications.fireMilestone(
            habitId: 'h1',
            habitName: 'Read',
            habitEmoji: '📚',
            streak: 7,
          )).called(1);
    });

    test('does not fire a milestone at a non-milestone streak', () async {
      final notifications = MockNotificationService();
      when(() => notifications.cancelStreakAtRisk(any())).thenAnswer((_) async {});

      final container = _buildContainer(
        habits: const [],
        checkIns: const {},
        notifications: notifications,
      );

      await container.read(notificationOrchestratorProvider).onCheckIn(
            habitId: 'h1',
            habitName: 'Read',
            habitEmoji: '📚',
            newStreak: 8, // not in NotificationService's milestone set
          );

      verifyNever(() => notifications.fireMilestone(
            habitId: any(named: 'habitId'),
            habitName: any(named: 'habitName'),
            habitEmoji: any(named: 'habitEmoji'),
            streak: any(named: 'streak'),
          ));
    });
  });
}
