import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/firebase/firestore_providers.dart';
import '../../../core/prefs/shared_preferences_provider.dart';

// ─── Keys ─────────────────────────────────────────────────────────────────────

const _kName = 'profile_name';
const _kAge = 'profile_age';
const _kGender = 'profile_gender';
// goals stored as comma-separated string, e.g. "Build healthy habits,Stay consistent"
const _kGoals = 'profile_goals';
const _kPhotoUrl = 'profile_photo_url';

// ─── Model ────────────────────────────────────────────────────────────────────

class UserProfile {
  const UserProfile({
    this.name = '',
    this.age = '',
    this.gender = '',
    this.goals = const [],
    this.photoUrl,
  });

  final String name;
  final String age;
  final String gender;

  /// Selected goals — can be multiple.
  final List<String> goals;

  /// Google account profile photo URL, captured at sign-in/link time.
  /// Null for guests and for accounts that haven't signed in with Google.
  final String? photoUrl;

  UserProfile copyWith({
    String? name,
    String? age,
    String? gender,
    List<String>? goals,
    String? photoUrl,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      goals: goals ?? this.goals,
      photoUrl: photoUrl ?? this.photoUrl,
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

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'age': age,
    'gender': gender,
    'goals': goals,
    'photoUrl': photoUrl,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  factory UserProfile.fromFirestore(Map<String, dynamic> data) {
    final rawGoals = data['goals'];
    List<String> goals;
    if (rawGoals is List) {
      goals = rawGoals.map((e) => e.toString()).toList();
    } else if (rawGoals is String && rawGoals.isNotEmpty) {
      // Legacy comma-separated format
      goals = rawGoals
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      goals = [];
    }
    return UserProfile(
      name: (data['name'] as String?) ?? '',
      age: (data['age'] as String?) ?? '',
      gender: (data['gender'] as String?) ?? '',
      goals: List.unmodifiable(goals),
      photoUrl: data['photoUrl'] as String?,
    );
  }
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

  /// Firestore document reference for the given uid.
  DocumentReference<Map<String, dynamic>> _doc(String uid) => ref
      .read(firestoreProvider)
      .collection('users')
      .doc(uid)
      .collection('profile')
      .doc('data');

  /// Write profile to Firestore for [uid]. Called by [app.dart] after sign-in.
  Future<void> pushToFirestore(String uid) async {
    try {
      await _doc(uid).set(state.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[UserProfile] pushToFirestore failed: $e');
    }
  }

  /// Pull profile from Firestore for [uid] and hydrate local state + prefs.
  /// Called by [app.dart] when a non-anonymous user signs in.
  Future<void> syncFromFirestore(String uid) async {
    try {
      final snap = await _doc(uid).get();
      if (!snap.exists || snap.data() == null) {
        // No remote profile yet — push local data up so it's stored.
        await pushToFirestore(uid);
        return;
      }
      final remote = UserProfile.fromFirestore(snap.data()!);
      // Hydrate SharedPreferences so the profile survives app restarts.
      await _prefs.setString(_kName, remote.name);
      await _prefs.setString(_kAge, remote.age);
      await _prefs.setString(_kGender, remote.gender);
      await _prefs.setString(_kGoals, remote.goals.join(','));
      if (remote.photoUrl != null) {
        await _prefs.setString(_kPhotoUrl, remote.photoUrl!);
      }
      state = remote;
    } catch (e) {
      debugPrint('[UserProfile] syncFromFirestore failed: $e');
    }
  }

  Future<void> setName(String v, {String? uid}) async {
    final trimmed = v.trim();
    await _prefs.setString(_kName, trimmed);
    state = state.copyWith(name: trimmed);
    if (uid != null) unawaited(pushToFirestore(uid));
  }

  Future<void> setAge(String v, {String? uid}) async {
    final trimmed = v.trim();
    await _prefs.setString(_kAge, trimmed);
    state = state.copyWith(age: trimmed);
    if (uid != null) unawaited(pushToFirestore(uid));
  }

  Future<void> setGender(String v, {String? uid}) async {
    await _prefs.setString(_kGender, v);
    state = state.copyWith(gender: v);
    if (uid != null) unawaited(pushToFirestore(uid));
  }

  /// Replace the full goals list.
  Future<void> setGoals(List<String> v, {String? uid}) async {
    await _prefs.setString(_kGoals, v.join(','));
    state = state.copyWith(goals: List.unmodifiable(v));
    if (uid != null) unawaited(pushToFirestore(uid));
  }

  /// Captures the Google account's profile photo URL. Called from
  /// [app.dart]'s auth listener on every non-anonymous sign-in so it stays
  /// in sync with whatever Firebase Auth currently reports — not part of
  /// the onboarding questionnaire, since guests never have one.
  Future<void> setPhotoUrl(String? v, {String? uid}) async {
    if (v == null || v.isEmpty) return;
    await _prefs.setString(_kPhotoUrl, v);
    state = state.copyWith(photoUrl: v);
    if (uid != null) unawaited(pushToFirestore(uid));
  }

  /// Toggle a single goal in/out of the list.
  Future<void> toggleGoal(String goal, {String? uid}) async {
    final current = List<String>.from(state.goals);
    if (current.contains(goal)) {
      current.remove(goal);
    } else {
      current.add(goal);
    }
    await setGoals(current, uid: uid);
  }

  Future<void> reset() async {
    await _prefs.remove(_kName);
    await _prefs.remove(_kAge);
    await _prefs.remove(_kGender);
    await _prefs.remove(_kGoals);
    await _prefs.remove(_kPhotoUrl);
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
    photoUrl: prefs.getString(_kPhotoUrl),
  );
}

/// Call in main() after SharedPreferences is ready to seed the initial state.
UserProfile readUserProfileFromPrefs(SharedPreferences prefs) =>
    _fromPrefs(prefs);

// ─── Provider ─────────────────────────────────────────────────────────────────

final userProfileProvider = NotifierProvider<UserProfileNotifier, UserProfile>(
  UserProfileNotifier.new,
);

// ─── unawaited helper ─────────────────────────────────────────────────────────

void unawaited(Future<void> future) {
  future.catchError(
    (e) => debugPrint('[UserProfile] background write failed: $e'),
  );
}
