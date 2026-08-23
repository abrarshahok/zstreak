import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zstreak/core/prefs/shared_preferences_provider.dart';
import 'package:zstreak/features/analytics/analytics_service.dart';
import 'package:zstreak/features/habits/application/check_in_actions.dart';
import 'package:zstreak/features/habits/application/habit_providers.dart';
import 'package:zstreak/features/habits/domain/check_in.dart';
import 'package:zstreak/features/habits/domain/check_in_status.dart';
import 'package:zstreak/features/habits/domain/frequency.dart';
import 'package:zstreak/features/habits/domain/habit.dart';
import 'package:zstreak/features/habits/domain/habit_category.dart';
import 'package:zstreak/features/habits/domain/habit_repository.dart';
import 'package:zstreak/features/habits/domain/streak_calculator.dart';
import 'package:zstreak/features/monetization/application/entitlement_providers.dart';
import 'package:zstreak/features/notifications/application/notification_providers.dart';
import 'package:zstreak/features/notifications/data/notification_service.dart';
import 'package:zstreak/features/reviews/review_prompt_service.dart';

class MockAnalyticsService extends Mock implements AnalyticsService {}

class MockReviewPromptService extends Mock implements ReviewPromptService {}

class MockNotificationService extends Mock implements NotificationService {}

/// Records every [setCheckIn] call and serves back a fixed habit for
/// [getHabitById] — just enough of [HabitRepository] for [performCheckIn]'s
/// own logic, not a full fake of the interface's other members.
class RecordingHabitRepository implements HabitRepository {
  RecordingHabitRepository(this._habitAfterCheckIn);

  final Habit _habitAfterCheckIn;
  final List<({String habitId, String date, CheckInStatus status})>
  setCheckInCalls = [];

  @override
  Future<void> setCheckIn({
    required String habitId,
    required String date,
    required CheckInStatus status,
    String? note,
    int? value,
  }) async {
    setCheckInCalls.add((habitId: habitId, date: date, status: status));
  }

  @override
  Future<Habit?> getHabitById(String id) async => _habitAfterCheckIn;

  @override
  Future<({bool completed, int currentStreak})> toggleCheckIn({
    required String habitId,
    required String date,
  }) => throw UnimplementedError();

  @override
  Stream<List<Habit>> watchActiveHabits() => throw UnimplementedError();
  @override
  Stream<List<Habit>> watchArchivedHabits() => throw UnimplementedError();
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
  Stream<CheckIn?> watchCheckIn({required String habitId, required String date}) =>
      throw UnimplementedError();
  @override
  Stream<List<CheckIn>> watchHabitCheckIns(String habitId) => throw UnimplementedError();
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
  Stream<StreakResult> watchStreakDetail({
    required String habitId,
    required FrequencyType frequencyType,
    required FrequencyConfig frequencyConfig,
    required DateTime createdAt,
  }) => throw UnimplementedError();
  @override
  Future<void> reorderHabits(List<String> orderedIds) => throw UnimplementedError();
  @override
  Stream<List<HabitCategory>> watchCategories() => throw UnimplementedError();
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

Habit _habit({int currentStreak = 8}) {
  final now = DateTime.now();
  return Habit(
    id: 'h1',
    name: 'Read',
    emoji: '📚',
    colorHex: '#B57BFF',
    frequencyType: FrequencyType.daily,
    frequencyConfig: const DailyConfig(),
    currentStreak: currentStreak,
    createdAt: now.subtract(const Duration(days: 30)),
    updatedAt: now,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(DateTime.now());
  });

  Future<(BuildContext, WidgetRef)> pumpHost(
    WidgetTester tester,
    List<Override> overrides,
  ) async {
    late BuildContext capturedContext;
    late WidgetRef capturedRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              capturedContext = context;
              capturedRef = ref;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return (capturedContext, capturedRef);
  }

  testWidgets('checking a habit off runs the full side-effect pipeline once', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final repo = RecordingHabitRepository(_habit(currentStreak: 8)); // not a milestone
    final analytics = MockAnalyticsService();
    final reviewPrompt = MockReviewPromptService();
    final notifications = MockNotificationService();

    when(() => analytics.logStreakMilestone(
          habitId: any(named: 'habitId'),
          streak: any(named: 'streak'),
        )).thenAnswer((_) async {});
    when(() => reviewPrompt.maybePromptAfterStreakMilestone(any())).thenAnswer((_) async {});
    when(() => notifications.cancelStreakAtRisk(any())).thenAnswer((_) async {});

    final (context, ref) = await pumpHost(tester, [
      habitRepositoryProvider.overrideWithValue(repo),
      analyticsServiceProvider.overrideWithValue(analytics),
      reviewPromptServiceProvider.overrideWithValue(reviewPrompt),
      notificationServiceProvider.overrideWithValue(notifications),
      hasActiveEntitlementProvider.overrideWith((ref) async => false),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);

    await performCheckIn(
      context: context,
      ref: ref,
      habit: _habit(currentStreak: 8),
      date: '2026-03-10',
      isDone: false, // false = not yet done → this call marks it done
    );

    expect(repo.setCheckInCalls, [
      (habitId: 'h1', date: '2026-03-10', status: CheckInStatus.completed),
    ]);
    verify(() => reviewPrompt.maybePromptAfterStreakMilestone(8)).called(1);
    verify(() => analytics.logStreakMilestone(habitId: 'h1', streak: 8)).called(1);
    verify(() => notifications.cancelStreakAtRisk('h1')).called(1);
  });

  testWidgets('unchecking a habit only writes status:missed — no side effects', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final repo = RecordingHabitRepository(_habit());
    final analytics = MockAnalyticsService();
    final reviewPrompt = MockReviewPromptService();
    final notifications = MockNotificationService();

    final (context, ref) = await pumpHost(tester, [
      habitRepositoryProvider.overrideWithValue(repo),
      analyticsServiceProvider.overrideWithValue(analytics),
      reviewPromptServiceProvider.overrideWithValue(reviewPrompt),
      notificationServiceProvider.overrideWithValue(notifications),
      hasActiveEntitlementProvider.overrideWith((ref) async => false),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);

    await performCheckIn(
      context: context,
      ref: ref,
      habit: _habit(),
      date: '2026-03-10',
      isDone: true, // true = already done → this call undoes it
    );

    expect(repo.setCheckInCalls, [
      (habitId: 'h1', date: '2026-03-10', status: CheckInStatus.missed),
    ]);
    verifyNever(() => reviewPrompt.maybePromptAfterStreakMilestone(any()));
    verifyNever(() => analytics.logStreakMilestone(
          habitId: any(named: 'habitId'),
          streak: any(named: 'streak'),
        ));
    verifyNever(() => notifications.cancelStreakAtRisk(any()));
  });
}
