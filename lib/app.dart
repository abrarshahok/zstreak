import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_providers.dart';
import 'features/analytics/analytics_service.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/habits/application/habit_providers.dart';
import 'features/habits/presentation/habit_detail_screen.dart';
import 'features/monetization/application/entitlement_providers.dart';
import 'features/notifications/application/notification_providers.dart';
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
    ref.read(notificationServiceProvider).initialize(onHabitTapped: _openHabit);
    ref.read(revenueCatServiceProvider).initialize();
    _checkWidgetConfigureLaunch();
  }

  /// Android launches us specially the moment a widget instance is
  /// placed (spec Section 2) — that takes over the whole app instead of
  /// the normal auth-gated flow until a habit is chosen.
  Future<void> _checkWidgetConfigureLaunch() async {
    final idString = await HomeWidget.initiallyLaunchedFromHomeWidgetConfigure();
    final id = idString == null ? null : int.tryParse(idString);
    if (id != null && mounted) setState(() => _configuringWidgetId = id);
  }

  Future<void> _openHabit(String habitId) async {
    final habit = await ref.read(habitRepositoryProvider).getHabitById(habitId);
    if (habit == null) return;
    ref
        .read(navigatorKeyProvider)
        .currentState
        ?.push(MaterialPageRoute(builder: (_) => HabitDetailScreen(habit: habit)));
  }

  @override
  Widget build(BuildContext context) {
    // Entitlements follow the Firebase uid (spec Section 2) — including
    // the anonymous guest uid, so a guest's purchase survives a normal
    // link since Stage 6 never changes the uid on that path.
    ref.listen(authStateProvider, (previous, next) {
      final uid = next.valueOrNull?.uid;
      final service = ref.read(revenueCatServiceProvider);
      if (uid != null) {
        service.logIn(uid);
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
