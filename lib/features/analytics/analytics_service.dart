import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase Analytics (spec Section 2/9) — wired from the start, not
/// bolted on later, same as Crashlytics. Section 9's success metrics
/// name specific things to instrument explicitly, most importantly
/// guest-to-linked conversion (tracked separately from trial-to-paid,
/// and WHEN it happens) since a user must convert from guest to linked
/// before they can become a long-term paying subscriber at all.
class AnalyticsService {
  AnalyticsService({FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  Future<void> logGuestStarted() => _analytics.logEvent(name: 'guest_started');

  Future<void> logSignUp(String method) =>
      _analytics.logSignUp(signUpMethod: method);

  Future<void> logLogin(String method) =>
      _analytics.logLogin(loginMethod: method);

  /// [timing] is one of `immediate` / `mid_window` / `forced_expiry` —
  /// Section 9 asks to tune the Stage 5 escalation timing off this.
  Future<void> logGuestLinked({
    required String method,
    required String timing,
  }) => _analytics.logEvent(
    name: 'guest_linked',
    parameters: {'method': method, 'timing': timing},
  );

  /// [habitNumber] is this account's Nth active habit — Section 9 tracks
  /// "% of users who create a 2nd habit" as a real-engagement signal.
  Future<void> logHabitCreated({required int habitNumber}) =>
      _analytics.logEvent(
        name: 'habit_created',
        parameters: {'habit_number': habitNumber},
      );

  Future<void> logTrialStarted(String productId) => _analytics.logEvent(
    name: 'trial_started',
    parameters: {'product_id': productId},
  );

  Future<void> logPurchaseCompleted(String productId) => _analytics.logEvent(
    name: 'purchase_completed',
    parameters: {'product_id': productId},
  );

  Future<void> logStreakMilestone({
    required String habitId,
    required int streak,
  }) => _analytics.logEvent(
    name: 'streak_milestone',
    parameters: {'habit_id': habitId, 'streak': streak},
  );

  Future<void> setUserId(String? uid) => _analytics.setUserId(id: uid);
}

final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(),
);
