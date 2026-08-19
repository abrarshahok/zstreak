import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/prefs/shared_preferences_provider.dart';

// ─── Keys ─────────────────────────────────────────────────────────────────────

const _kName = 'profile_name';
const _kAge = 'profile_age';
const _kGender = 'profile_gender';
// goals stored as comma-separated string, e.g. "Build healthy habits,Stay consistent"
const _kGoals = 'profile_goals';

// ─── Model ────────────────────────────────────────────────────────────────────

class UserProfile {
  const UserProfile({
    this.name = '',
    this.age = '',
    this.gender = '',
    this.goals = const [],
  });

  final String name;
  final String age;
  final String gender;

  /// Selected goals — can be multiple.
  final List<String> goals;

  UserProfile copyWith({
    String? name,
    String? age,
    String? gender,
    List<String>? goals,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      goals: goals ?? this.goals,
    );
  }

  /// First name only, trimmed.
  String get firstName {
    final parts = name.trim().split(' ');
    return parts.isNotEmpty ? parts.first : '';
  }

  bool get hasName => name.trim().isNotEmpty;

  /// Human-readable display string for goals (comma + space joined).
  String get goalsDisplay => goals.isEmpty ? '' : goals.join(', ');

  /// Legacy single-goal accessor — returns first goal or empty string.
  /// Used by places that still read a single value.
  String get goal => goals.isEmpty ? '' : goals.first;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class UserProfileNotifier extends Notifier<UserProfile> {
  @override
  UserProfile build() {
    // Seed from SharedPreferences on first build
    final prefs = ref.read(sharedPreferencesProvider);
    return _fromPrefs(prefs);
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  Future<void> setName(String v) async {
    final trimmed = v.trim();
    await _prefs.setString(_kName, trimmed);
    state = state.copyWith(name: trimmed);
  }

  Future<void> setAge(String v) async {
    final trimmed = v.trim();
    await _prefs.setString(_kAge, trimmed);
    state = state.copyWith(age: trimmed);
  }

  Future<void> setGender(String v) async {
    await _prefs.setString(_kGender, v);
    state = state.copyWith(gender: v);
  }

  /// Replace the full goals list.
  Future<void> setGoals(List<String> v) async {
    await _prefs.setString(_kGoals, v.join(','));
    state = state.copyWith(goals: List.unmodifiable(v));
  }

  /// Toggle a single goal in/out of the list.
  Future<void> toggleGoal(String goal) async {
    final current = List<String>.from(state.goals);
    if (current.contains(goal)) {
      current.remove(goal);
    } else {
      current.add(goal);
    }
    await setGoals(current);
  }

  Future<void> reset() async {
    await _prefs.remove(_kName);
    await _prefs.remove(_kAge);
    await _prefs.remove(_kGender);
    await _prefs.remove(_kGoals);
    state = const UserProfile();
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

UserProfile _fromPrefs(SharedPreferences prefs) {
  final goalsRaw = prefs.getString(_kGoals) ?? '';
  final goals = goalsRaw.isEmpty
      ? <String>[]
      : goalsRaw
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
  return UserProfile(
    name: prefs.getString(_kName) ?? '',
    age: prefs.getString(_kAge) ?? '',
    gender: prefs.getString(_kGender) ?? '',
    goals: List.unmodifiable(goals),
  );
}

/// Call in main() after SharedPreferences is ready to seed the initial state.
UserProfile readUserProfileFromPrefs(SharedPreferences prefs) =>
    _fromPrefs(prefs);

// ─── Provider ─────────────────────────────────────────────────────────────────

final userProfileProvider = NotifierProvider<UserProfileNotifier, UserProfile>(
  UserProfileNotifier.new,
);
