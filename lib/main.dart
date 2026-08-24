import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/prefs/shared_preferences_provider.dart';
import 'core/theme/theme_mode_providers.dart';
import 'features/home_tour/application/home_tour_providers.dart';
import 'features/onboarding/application/onboarding_providers.dart';
import 'features/widgets/data/widget_background_callback.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Holds the native launch screen up through Firebase Auth resolving and
  // (for a signed-in user) the Firestore profile sync in AuthGate, instead
  // of handing off early to a separate Flutter-rendered loading screen.
  // AuthGate calls FlutterNativeSplash.remove() once it knows the real
  // destination, so startup is splash -> real screen with nothing in
  // between.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // These five calls are mutually independent — none reads another's
  // result — so they run concurrently instead of paying for each one's
  // latency in sequence on the critical path to the first frame.
  final results = await Future.wait<Object?>([
    // Draw Flutter content behind the status bar and navigation bar so the
    // app feels truly full-screen on physical devices. Each screen controls
    // its own overlay icon brightness via SystemUiOverlayStyle (set in
    // AppTheme or per screen). Without this, Android clips the Flutter
    // canvas at the system bar boundaries, causing the "overlapping"
    // appearance on API 29+ devices.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
    Firebase.initializeApp(),
    SharedPreferences.getInstance(),
    // Lets the widget's check-in tap run this callback in a headless
    // isolate without opening the app (spec Section 2/12).
    HomeWidget.registerInteractivityCallback(widgetInteractivityCallback),
    // Resolved *before* runApp() rather than reactively via setState once
    // the app is already showing — MaterialApp's Navigator only ever
    // consults `home` once, to build its initial '/' route, when it first
    // mounts. Changing `home` on a later rebuild (which is all a
    // post-launch setState could do) doesn't retroactively replace that
    // already-built route, so the widget-configure screen never actually
    // appeared; the app just sat on its normal AuthGate route while
    // home_widget's pending result stayed unresolved. Deciding this up
    // front means the very first build already has the right answer.
    HomeWidget.initiallyLaunchedFromHomeWidgetConfigure(),
  ]);
  final prefs = results[2] as SharedPreferences;
  final configureIdString = results[4] as String?;
  final configuringWidgetId = configureIdString == null
      ? null
      : int.tryParse(configureIdString);

  // App Check attaches its attestation token to every Firebase request from
  // here on, so it must be activated before anything below (Firestore,
  // Crashlytics) — and before Firebase.initializeApp() resolves it can't run
  // at all, so it belongs after the Future.wait above, not inside it.
  //
  // Firestore enforcement is ON (Console -> App Check). Play Integrity /
  // App Attest can't produce a valid attestation from a debug build /
  // emulator (no real Play Store install, possibly no Play Services at
  // all) — using them there wouldn't just be inconvenient, calls would be
  // rejected outright. The debug provider is the actual mechanism for
  // that case: it sends a fixed secret instead of a real attestation,
  // which is only accepted because that exact secret was separately
  // registered under Console -> App Check -> Manage debug tokens. Never
  // reaches the debug branch in a release build, so there's no risk of
  // shipping that bypass to a real device.
  //
  // Pass --dart-define=APP_CHECK_DEBUG_TOKEN=<value> to pin every debug
  // build to one already-registered token instead of each install
  // generating (and needing to separately register) its own — Firebase's
  // own CLI explicitly warns this value shouldn't be committed to source,
  // so it stays out of this file entirely; leaving it unset falls back to
  // per-install auto-generation, printed to the console on first launch.
  const debugToken = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? AndroidDebugProvider(
            debugToken: debugToken.isEmpty ? null : debugToken,
          )
        : const AndroidPlayIntegrityProvider(),
    // Falls back to Device Check on iOS <14/macOS <14 instead of failing
    // outright, since App Attest alone requires iOS 14+/macOS 14+.
    providerApple: kDebugMode
        ? AppleDebugProvider(debugToken: debugToken.isEmpty ? null : debugToken)
        : const AppleAppAttestWithDeviceCheckFallbackProvider(),
  );

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

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        onboardingCompleteProvider.overrideWith(
          (ref) => readOnboardingCompleteFromPrefs(prefs),
        ),
        homeTourSeenProvider.overrideWith(
          (ref) => readHomeTourSeenFromPrefs(prefs),
        ),
        themeModeProvider.overrideWith((ref) => readThemeModeFromPrefs(prefs)),
      ],
      child: ZStreakApp(configuringWidgetId: configuringWidgetId),
    ),
  );
}
