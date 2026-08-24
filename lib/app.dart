import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import 'features/widgets/application/widget_providers.dart';
import 'features/widgets/data/widget_pin_channel.dart';
import 'features/widgets/presentation/widget_configure_screen.dart';

final navigatorKeyProvider = Provider((ref) => GlobalKey<NavigatorState>());

class ZStreakApp extends ConsumerStatefulWidget {
  const ZStreakApp({super.key, this.configuringWidgetId});

  /// Resolved in main.dart *before* runApp() — see the comment there for
  /// why this can't be a reactive setState in this widget's own initState.
  final int? configuringWidgetId;

  @override
  ConsumerState<ZStreakApp> createState() => _ZStreakAppState();
}

class _ZStreakAppState extends ConsumerState<ZStreakApp> {
  @override
  void initState() {
    super.initState();
    _initNotifications();
    _refreshNotifications();
    _syncWidgets();
    listenForPinnedHabitWidget(_onWidgetPinned);
  }

  /// The Settings "Add home screen widget" button requests a pin directly
  /// (see widget_pin_channel.dart for why) rather than the user dragging
  /// one from the OS widget tray, so this is the substitute for the
  /// configure screen the launcher doesn't invoke on its own for that
  /// flow — push it onto whatever's currently showing, exactly like a
  /// notification tap already does via [navigatorKeyProvider].
  void _onWidgetPinned(int widgetId) {
    ref
        .read(navigatorKeyProvider)
        .currentState
        ?.push(
          MaterialPageRoute(
            builder: (_) => WidgetConfigureScreen(widgetId: widgetId),
          ),
        );
  }

  /// Cold-start reconciliation for any already-placed widgets — the only
  /// caller of [WidgetSyncService.syncHabits], which otherwise exists but
  /// is never invoked. Per-mutation syncing (create/check-in/edit/archive)
  /// covers habits that change while the app is open, but a widget placed
  /// for a habit that hasn't been touched since — or whose premium_active
  /// flag never got set because no mutation had run yet — would otherwise
  /// sit stale or show the locked/placeholder state indefinitely.
  Future<void> _syncWidgets() async {
    try {
      final repo = ref.read(habitRepositoryProvider);
      final habits = await repo.watchActiveHabits().first;
      final isPremium = await ref.read(hasActiveEntitlementProvider.future);
      await ref
          .read(widgetSyncServiceProvider)
          .syncHabits(
            habits,
            (id, date) => repo.watchCheckIn(habitId: id, date: date).first,
            (id) => repo.watchHabitCheckIns(id).first,
            isPremium: isPremium,
          );
    } catch (_) {
      // Best-effort — a widget refresh failing must never block startup.
    }
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
    // Keeps RevenueCat's own identity in sync with the current Firebase
    // uid — see revenueCatIdentitySyncProvider's doc comment for why this
    // needs to be its own watched provider rather than a plain side
    // effect fired from the listener below. Must be watched *somewhere*
    // for this FutureProvider to actually run and re-run on every auth
    // change; here, rather than only inside whatever provider first
    // awaits it, so the resync starts the instant auth state changes.
    ref.watch(revenueCatIdentitySyncProvider);

    // Entitlements follow the Firebase uid (spec Section 2) — including
    // the anonymous guest uid, so a guest's purchase survives a normal
    // link since Stage 6 never changes the uid on that path.
    ref.listen(authStateProvider, (previous, next) {
      final user = next.valueOrNull;
      final uid = user?.uid;
      if (uid != null) {
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
          // Held true until the chain below finishes (however it finishes)
          // so AuthGate holds off on profileCompleteProvider — see
          // profileHydratingProvider's own doc comment for why.
          ref.read(profileHydratingProvider.notifier).state = true;
          ref
              .read(accountStatusRepositoryProvider)
              .getStatus(uid)
              .then((status) {
                if (!status.isActive) return Future<void>.value();
                final profileNotifier = ref.read(userProfileProvider.notifier);
                return profileNotifier.syncFromFirestore(uid).then((_) {
                  // Google's photo isn't part of the onboarding questionnaire,
                  // so it's kept separately in sync with whatever Firebase
                  // Auth currently reports — after the Firestore sync above,
                  // so an older remote profile with no photoUrl never
                  // clobbers it.
                  //
                  // user.photoURL itself is only ever populated at account
                  // *creation* time — this app's primary path is guest-first
                  // (anonymous sign-in, then linkWithCredential later), and
                  // Firebase never copies a linked provider's profile photo
                  // onto the base User object, only onto that provider's own
                  // entry in providerData. Falling back to the google.com
                  // provider's photoURL there is what actually makes this
                  // work for the common linked-guest path, not just a
                  // fresh direct sign-in.
                  String? googlePhotoUrl = user?.photoURL;
                  if (googlePhotoUrl == null) {
                    for (final info in user?.providerData ?? const []) {
                      if (info.providerId == 'google.com' &&
                          info.photoURL != null) {
                        googlePhotoUrl = info.photoURL;
                        break;
                      }
                    }
                  }
                  profileNotifier.setPhotoUrl(googlePhotoUrl, uid: uid);
                });
              })
              .whenComplete(() {
                ref.read(profileHydratingProvider.notifier).state = false;
              });
        }
      }
      ref.read(analyticsServiceProvider).setUserId(uid);
    });

    // Fallback so the opaque-nav-bar styling (see AppTheme's overlay style
    // constants) still applies on screens with no AppBar of their own
    // (onboarding, sign-in, etc.) — an AppBar's systemOverlayStyle only
    // takes effect while that specific AppBar is mounted, so without this
    // those screens fell back to the OS default (which is transparent),
    // and the nav bar visibly flickered between opaque and see-through
    // depending on which screen was showing.
    final themeMode = ref.watch(themeModeProvider);
    final isDark = switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? AppTheme.systemOverlayStyleDark
          : AppTheme.systemOverlayStyleLight,
      child: MaterialApp(
        navigatorKey: ref.watch(navigatorKeyProvider),
        title: 'ZStreak',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: widget.configuringWidgetId != null
            ? WidgetConfigureScreen(widgetId: widget.configuringWidgetId!)
            : const AuthGate(),
      ),
    );
  }
}
