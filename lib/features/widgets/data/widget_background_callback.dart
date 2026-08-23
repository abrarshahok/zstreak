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
import 'widget_sync_service.dart';

/// `home_widget`'s background broadcast receiver (see AndroidManifest.xml)
/// is `exported="true"` with no permission of its own — any other app
/// installed on the same device can send this same broadcast with an
/// arbitrary `habitId`, not just the real widget UI. Every genuine habit
/// id is a uuid v4 ([DriftHabitRepository.createHabit],
/// [MigrationService]), so this shape check costs nothing for a real tap
/// (no DB round-trip) while rejecting an obviously-forged/garbage id
/// before it ever reaches the database.
final _uuidV4Pattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Runs in a headless background isolate when the widget's check-in
/// button is tapped (spec Section 2, "tappable to mark complete without
/// opening the app") — registered via [HomeWidget.registerInteractivityCallback]
/// in `main()`. Has no Riverpod container here, so it builds the backend
/// directly rather than going through the app's providers.
@pragma('vm:entry-point')
Future<void> widgetInteractivityCallback(Uri? uri) async {
  if (uri == null || uri.host != 'checkin') return;
  final habitId = uri.queryParameters['habitId'];
  if (habitId == null || !_uuidV4Pattern.hasMatch(habitId)) return;

  // This isolate has no crash-reporting hook and no user-visible surface
  // to show an error on — a malformed/forged broadcast that still passes
  // the shape check above, or a transient Firestore/DB error, should
  // silently no-op this one tap rather than crash the isolate outright.
  try {
    WidgetsFlutterBinding.ensureInitialized();
    // Skips re-initializing Firebase when this isolate/engine is already
    // set up from a previous tap — a real, if sometimes small, chunk of
    // the delay a user feels between tapping check-in and seeing it
    // reflected, on top of the unavoidable headless-isolate spin-up cost.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }

    final user = FirebaseAuth.instance.currentUser;
    final HabitRepository repo = (user != null && !user.isAnonymous)
        ? FirestoreHabitRepository(FirebaseFirestore.instance, user.uid)
        : DriftHabitRepository(AppDatabase());

    final today = todayLocalDateString();
    // toggleCheckIn (not a read-then-negate-then-setCheckIn here) reads
    // and flips the completed value inside a single database transaction.
    // Each tap on the widget's button runs this callback in its own
    // headless isolate with no shared in-memory state, so a plain
    // read-then-write here would let two fast taps both read the same
    // pre-toggle value and collide on the same result — a tap that should
    // have cancelled a previous one instead silently gets lost.
    //
    // getHabitById doesn't need to wait for that toggle to finish first —
    // a check-in never changes a habit's name/emoji/color/frequency, only
    // its streak (which toggleCheckIn already returns directly, so this
    // read's own currentStreak field is simply discarded below rather
    // than relied on). Starting both here instead of awaiting one before
    // the other removes one whole sequential network round-trip from the
    // critical path — real, felt latency for a signed-in (Firestore)
    // user, not just visual redraw cost.
    final toggleFuture = repo.toggleCheckIn(habitId: habitId, date: today);
    final habitFuture = repo.getHabitById(habitId);
    final toggleResult = await toggleFuture;
    final habit = await habitFuture;
    if (habit == null) return;

    final checkIns = await repo.watchHabitCheckIns(habitId).first;

    // Writes name/emoji/color/streak/completedToday/grid in one shared
    // place (writeHabitData) instead of re-deriving a partial subset here
    // — a previous hand-rolled version only wrote streak + completedToday,
    // which is why the check icon updated on a widget tap but the
    // contribution grid kept showing stale data.
    await WidgetSyncService().writeHabitData(
      habit.copyWith(
        currentStreak: toggleResult.currentStreak,
        updatedAt: habit.updatedAt,
      ),
      completedToday: toggleResult.completed,
      checkIns: checkIns,
    );
    await HomeWidget.updateWidget(
      qualifiedAndroidName: 'com.zstreak.app.HabitWidgetProvider',
    );

    // For a signed-in (Firestore) user, toggleCheckIn and its streak
    // recompute each ran their own runTransaction — every Firestore
    // transaction sets up an internal platform-channel stream that
    // disposes itself asynchronously *after* its Future resolves, not
    // synchronously as part of it. This isolate's engine gets torn down
    // by home_widget's WorkManager worker as soon as this function
    // returns, which can beat that disposal to the punch, so this delay
    // holds the engine open long enough for both transactions' trailing
    // cleanup to finish before it's destroyed, instead of it firing a
    // harmless-but-noisy MissingPluginException ("... method cancel ...")
    // mid-teardown. 300ms wasn't consistently enough in practice — bumped
    // to 1s, which is still never felt as check-in latency since the
    // widget's visible update already fired above.
    await Future<void>.delayed(const Duration(milliseconds: 1000));
  } catch (_) {
    // Swallowed — see comment above.
  }
}
