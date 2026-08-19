import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/prefs/shared_preferences_provider.dart';

const kOnboardingCompleteKey = 'onboarding_complete';

/// True once a user has been through the post-auth sequence once
/// (notification prompt + first habit, spec Section 3 screens 3-4) —
/// seeded from disk at boot in `main()` so it survives app restarts.
final onboardingCompleteProvider = StateProvider<bool>(
  (ref) => throw UnimplementedError('Overridden in main() before runApp.'),
);

Future<void> markOnboardingComplete(WidgetRef ref) async {
  await ref.read(sharedPreferencesProvider).setBool(kOnboardingCompleteKey, true);
  ref.read(onboardingCompleteProvider.notifier).state = true;
}

bool readOnboardingCompleteFromPrefs(SharedPreferences prefs) =>
    prefs.getBool(kOnboardingCompleteKey) ?? false;
