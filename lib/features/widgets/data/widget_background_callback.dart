import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import '../../../core/utils/local_date.dart';
import '../../habits/data/local/app_database.dart';
import '../../habits/data/local/drift_habit_repository.dart';
import '../../habits/data/remote/firestore_habit_repository.dart';
import '../../habits/domain/habit_repository.dart';

/// Runs in a headless background isolate when the widget's check-in
/// button is tapped (spec Section 2, "tappable to mark complete without
/// opening the app") — registered via [HomeWidget.registerInteractivityCallback]
/// in `main()`. Has no Riverpod container here, so it builds the backend
/// directly rather than going through the app's providers.
@pragma('vm:entry-point')
Future<void> widgetInteractivityCallback(Uri? uri) async {
  if (uri == null || uri.host != 'checkin') return;
  final habitId = uri.queryParameters['habitId'];
  if (habitId == null) return;

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final user = FirebaseAuth.instance.currentUser;
  final HabitRepository repo = (user != null && !user.isAnonymous)
      ? FirestoreHabitRepository(FirebaseFirestore.instance, user.uid)
      : DriftHabitRepository(AppDatabase());

  final today = todayLocalDateString();
  final existing = await repo.watchCheckIn(habitId: habitId, date: today).first;
  await repo.setCheckIn(habitId: habitId, date: today, completed: !(existing?.completed ?? false));

  final habit = await repo.getHabitById(habitId);
  if (habit == null) return;
  final checkIn = await repo.watchCheckIn(habitId: habitId, date: today).first;

  await HomeWidget.saveWidgetData<String>('habit_${habit.id}_streak', habit.currentStreak.toString());
  await HomeWidget.saveWidgetData<String>(
    'habit_${habit.id}_completed_today',
    (checkIn?.completed ?? false).toString(),
  );
  await HomeWidget.updateWidget(qualifiedAndroidName: 'com.zstreak.app.HabitWidgetProvider');
}
