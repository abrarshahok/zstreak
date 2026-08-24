import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/prefs/shared_preferences_provider.dart';

const kHomeTourSeenKey = 'home_tour_seen';

/// True once the first-run Home spotlight walkthrough has been shown (or
/// skipped) — seeded from disk at boot in `main()`, same pattern as
/// [onboardingCompleteProvider], so it survives app restarts and only ever
/// fires once per install.
final homeTourSeenProvider = StateProvider<bool>(
  (ref) => throw UnimplementedError('Overridden in main() before runApp.'),
);

Future<void> markHomeTourSeen(WidgetRef ref) async {
  await ref.read(sharedPreferencesProvider).setBool(kHomeTourSeenKey, true);
  ref.read(homeTourSeenProvider.notifier).state = true;
}

bool readHomeTourSeenFromPrefs(SharedPreferences prefs) =>
    prefs.getBool(kHomeTourSeenKey) ?? false;

/// GlobalKeys the walkthrough targets, shared between [HomeScreen] (which
/// attaches them to the widgets being spotlighted) and the tour overlay
/// (which builds its steps from them). Held behind a plain [Provider] so
/// the same key instances survive HomeScreen's frequent rebuilds — keys
/// created inline in a `build()` method would be recreated every rebuild
/// and lose their target.
class HomeTourKeys {
  final fabKey = GlobalKey();
  final firstHabitKey = GlobalKey();
  final viewToggleKey = GlobalKey();
  final analyticsKey = GlobalKey();
  final archiveKey = GlobalKey();
  final settingsKey = GlobalKey();
}

final homeTourKeysProvider = Provider<HomeTourKeys>((ref) => HomeTourKeys());
