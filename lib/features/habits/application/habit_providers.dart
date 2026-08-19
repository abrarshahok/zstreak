import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../../monetization/application/entitlement_providers.dart';
import '../../widgets/application/widget_providers.dart';
import '../../widgets/data/widget_syncing_habit_repository.dart';
import '../data/local/app_database.dart';
import '../data/local/drift_habit_repository.dart';
import '../data/remote/firestore_habit_repository.dart';
import '../domain/check_in.dart';
import '../domain/habit.dart';
import '../domain/habit_repository.dart';
import '../domain/streak_calculator.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Backend swap point (spec Section 5's "identical shape, different
/// backend"): guests read/write Drift, signed-in/linked users read/write
/// Firestore. Every screen depends only on [HabitRepository], so this is
/// the only place that needs to know which backend is active.
final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  final HabitRepository backend = (user != null && !user.isAnonymous)
      ? FirestoreHabitRepository(ref.watch(firestoreProvider), user.uid)
      : DriftHabitRepository(ref.watch(appDatabaseProvider));

  return WidgetSyncingHabitRepository(
    backend,
    ref.watch(widgetSyncServiceProvider),
    ref.watch(entitlementRepositoryProvider),
  );
});

final activeHabitsProvider = StreamProvider<List<Habit>>((ref) {
  return ref.watch(habitRepositoryProvider).watchActiveHabits();
});

final archivedHabitsProvider = StreamProvider<List<Habit>>((ref) {
  return ref.watch(habitRepositoryProvider).watchArchivedHabits();
});

class CheckInQuery {
  const CheckInQuery(this.habitId, this.date);
  final String habitId;
  final String date;

  @override
  bool operator ==(Object other) =>
      other is CheckInQuery && other.habitId == habitId && other.date == date;

  @override
  int get hashCode => Object.hash(habitId, date);
}

final checkInProvider = StreamProvider.family<CheckIn?, CheckInQuery>((
  ref,
  query,
) {
  return ref
      .watch(habitRepositoryProvider)
      .watchCheckIn(habitId: query.habitId, date: query.date);
});

final streakDetailProvider = StreamProvider.family<StreakResult, Habit>((
  ref,
  habit,
) {
  return ref
      .watch(habitRepositoryProvider)
      .watchStreakDetail(
        habitId: habit.id,
        frequencyType: habit.frequencyType,
        frequencyConfig: habit.frequencyConfig,
        createdAt: habit.createdAt,
      );
});

/// Feature 2 – Habit Notes: watches all check-ins for a habit so the
/// detail screen can show note indicators on grid cells and display note
/// text on tap.
final habitCheckInsProvider = StreamProvider.family<List<CheckIn>, String>((
  ref,
  habitId,
) {
  return ref.watch(habitRepositoryProvider).watchHabitCheckIns(habitId);
});
