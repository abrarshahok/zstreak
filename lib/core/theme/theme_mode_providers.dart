import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../prefs/shared_preferences_provider.dart';

const _kThemeModeKey = 'theme_mode';

// System is the default — fresh installs follow the device's own
// light/dark setting. Only an explicit stored choice overrides it.
ThemeMode _themeModeFromString(String? value) => switch (value) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

String _themeModeToString(ThemeMode mode) => switch (mode) {
  ThemeMode.light => 'light',
  ThemeMode.dark => 'dark',
  ThemeMode.system => 'system',
};

ThemeMode readThemeModeFromPrefs(SharedPreferences prefs) =>
    _themeModeFromString(prefs.getString(_kThemeModeKey));

/// System is the default experience — follows device light/dark setting.
/// User can override to explicit light/dark via Settings; choice is persisted.
final themeModeProvider = StateProvider<ThemeMode>(
  (ref) => throw UnimplementedError('Overridden in main() before runApp.'),
);

Future<void> setThemeMode(WidgetRef ref, ThemeMode mode) async {
  await ref
      .read(sharedPreferencesProvider)
      .setString(_kThemeModeKey, _themeModeToString(mode));
  ref.read(themeModeProvider.notifier).state = mode;
}
