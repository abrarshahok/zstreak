import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_providers.dart';
import 'features/analytics/analytics_service.dart';
import 'features/auth/application/account_status_providers.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/habits/application/habit_providers.dart';
import 'features/habits/presentation/habit_detail_screen.dart';
import 'features/monetization/application/entitlement_providers.dart';
import 'features/notifications/application/notification_providers.dart';
import 'features/onboarding/application/user_profile_provider.dart';
import 'features/widgets/presentation/widget_configure_screen.dart';

final navigatorKeyProvider = Provider((ref) => GlobalKey<NavigatorState>());

class ZStreakApp extends ConsumerStatefulWidget {
  const ZStreakApp({super.key});

  @override
  ConsumerState<ZStreakApp> createState() => _ZStreakAppState();
}

class _ZStreakAppState extends ConsumerState<ZStreakApp> {
  int? _configuringWidgetId;

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _initRevenueCat();
    _checkWidgetConfigureLaunch();
    _refreshNotifications();
  }

  /// Initialize the notification plugin and request POST_NOTIFICATIONS
  /// permission on Android 13+ (API 33+). This is idempotent — Android
  /// only shows the system dialog once; if the user already granted or
  /// permanently denied it, the call is a silent no-op.
  Future<void> _initNotifications() async {
    final svc = ref.read(notificationServiceProvider);
    await svc.initialize(onHabitTapped: _openHabit);
    await svc.requestNotificationPermission();
  }

  Future<void> _refreshNotifications() async {
    // Run after the first frame so providers are fully settled.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(notificationOrchestratorProvider).refresh();
      } catch (_) {
        // Non-fatal — notifications are best-effort.
      }
    });
  }

  /// Initialize RevenueCat and immediately log in the current Firebase user
  /// (if one already exists). Without this, the first app launch after a
  /// cold start never calls [RevenueCatService.logIn] because the
  /// [authStateProvider] listener below only fires on *changes*, not on the
  /// already-resolved initial value.
  Future<void> _initRevenueCat() async {
    final service = ref.read(revenueCatServiceProvider);
    await service.initialize();
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid != null) {
      await service.logIn(uid);
    }
  }

  /// Android launches us specially the moment a widget instance is
  /// placed (spec Section 2) — that takes over the whole app instead of
  /// the normal auth-gated flow until a habit is chosen.
  Future<void> _checkWidgetConfigureLaunch() async {
    final idString =
        await HomeWidget.initiallyLaunchedFromHomeWidgetConfigure();
    final id = idString == null ? null : int.tryParse(idString);
    if (id != null && mounted) setState(() => _configuringWidgetId = id);
  }

  Future<void> _openHabit(String habitId) async {
    final habit = await ref.read(habitRepositoryProvider).getHabitById(habitId);
    if (habit == null) return;
    ref
        .read(navigatorKeyProvider)
        .currentState
        ?.push(
          MaterialPageRoute(builder: (_) => HabitDetailScreen(habit: habit)),
        );
  }

  @override
  Widget build(BuildContext context) {
    // Entitlements follow the Firebase uid (spec Section 2) — including
    // the anonymous guest uid, so a guest's purchase survives a normal
    // link since Stage 6 never changes the uid on that path.
    ref.listen(authStateProvider, (previous, next) {
      final user = next.valueOrNull;
      final uid = user?.uid;
      final service = ref.read(revenueCatServiceProvider);
      if (uid != null) {
        service.logIn(uid);
        // Sync user profile from Firestore when a non-anonymous user signs in.
        // This restores name/age/gender/goals on a new device or after reinstall.
        //
        // Checked against the account's *current* status first — a
        // deactivated/restricted account's profile doc is correctly
        // denied by Firestore's own rules, so attempting this sync
        // unconditionally just produced a guaranteed, noisy
        // permission-denied on every sign-in while inactive.
        // [AccountStatusGate] is what actually handles the UI for that
        // account state; this just avoids a doomed network call ahead of it.
        if (user?.isAnonymous == false) {
          ref.read(accountStatusRepositoryProvider).getStatus(uid).then((status) {
            if (!status.isActive) return;
            final profileNotifier = ref.read(userProfileProvider.notifier);
            profileNotifier.syncFromFirestore(uid).then((_) {
              // Google's photo isn't part of the onboarding questionnaire, so
              // it's kept separately in sync with whatever Firebase Auth
              // currently reports — after the Firestore sync above, so an
              // older remote profile with no photoUrl never clobbers it.
              profileNotifier.setPhotoUrl(user?.photoURL, uid: uid);
            });
          });
        }
      } else {
        service.logOut();
      }
      ref.read(analyticsServiceProvider).setUserId(uid);
    });

    return MaterialApp(
      navigatorKey: ref.watch(navigatorKeyProvider),
      title: 'ZStreak',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      home: _configuringWidgetId != null
          ? WidgetConfigureScreen(widgetId: _configuringWidgetId!)
          : const AuthGate(),
    );
  }
}
