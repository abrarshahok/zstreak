import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/prefs/shared_preferences_provider.dart';
import 'core/theme/theme_mode_providers.dart';
import 'features/onboarding/application/onboarding_providers.dart';
import 'features/widgets/data/widget_background_callback.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Draw Flutter content behind the status bar and navigation bar so the app
  // feels truly full-screen on physical devices. Each screen controls its own
  // overlay icon brightness via SystemUiOverlayStyle (set in AppTheme or per
  // screen). Without this, Android clips the Flutter canvas at the system bar
  // boundaries, causing the "overlapping" appearance on API 29+ devices.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await Firebase.initializeApp();

  // Explicit for clarity — on for signed-in users so check-ins stay
  // instant and reliable offline (spec Section 2); mobile defaults to on,
  // but this documents the requirement rather than relying on a default.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // Crashlytics wired from Stage 1, per spec Section 2 — not bolted on later.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  final prefs = await SharedPreferences.getInstance();

  // Lets the widget's check-in tap run this callback in a headless
  // isolate without opening the app (spec Section 2/12).
  await HomeWidget.registerInteractivityCallback(widgetInteractivityCallback);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        onboardingCompleteProvider.overrideWith(
          (ref) => readOnboardingCompleteFromPrefs(prefs),
        ),
        themeModeProvider.overrideWith((ref) => readThemeModeFromPrefs(prefs)),
      ],
      child: const ZStreakApp(),
    ),
  );
}
