import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/utils/local_date.dart';
import '../features/habits/domain/check_in_status.dart';
import '../features/habits/domain/frequency.dart';
import '../features/habits/domain/streak_calculator.dart';

/// One-off dev utility: populates a signed-in account with realistic
/// demo habits/check-ins/categories/mood-entries so every screen — and
/// every feature this app has — can be reviewed fully stocked instead of
/// empty. Wired to a "Seed demo data" row in Settings' debug section.
///
/// Deliberately covers the full feature surface, not just plain daily
/// habits: predefined AND custom categories, quantity/numeric habits,
/// quit-habit mode, explicit skip days (distinct from plain misses),
/// check-in notes, reminder times, archived habits, and a mood-entry
/// history that loosely correlates with a real habit so the Analytics
/// "Mood & Consistency" section has something genuine to show.
class _HabitSpec {
  _HabitSpec({
    required this.name,
    required this.emoji,
    required this.colorHex,
    required this.frequencyType,
    required this.frequencyConfig,
    required this.createdDaysAgo,
    this.completedDaysAgo = const {},
    this.skipDaysAgo = const {},
    this.valueByDaysAgo = const {},
    this.targetCount,
    this.targetUnit,
    this.isQuitHabit = false,
    this.categoryId,
    this.reminderTime,
    this.description,
    this.archivedDaysAgo,
    this.notedDaysAgo = const {},
  });

  final String name;
  final String emoji;
  final String colorHex;
  final FrequencyType frequencyType;
  final FrequencyConfig frequencyConfig;
  final int createdDaysAgo;

  /// Plain yes/no habits: days-ago offsets that were completed.
  final Set<int> completedDaysAgo;

  /// Days-ago offsets explicitly skipped (a deliberate "Skip" from the
  /// day-action sheet) rather than just missed (no check-in at all) —
  /// renders distinctly and never breaks a streak.
  final Set<int> skipDaysAgo;

  /// Quantity habits only: days-ago offset → logged value that day.
  /// Status is derived from value vs [targetCount] unless the same
  /// offset is also in [skipDaysAgo].
  final Map<int, int> valueByDaysAgo;

  /// Non-null together: makes this a quantity habit.
  final int? targetCount;
  final String? targetUnit;

  final bool isQuitHabit;

  /// Either a predefined category id (see `kPredefinedCategories`) or a
  /// custom one created by [_seedCustomCategories].
  final String? categoryId;

  /// "HH:mm", shows the reminder chip on Habit Detail.
  final String? reminderTime;

  final String? description;
  final int? archivedDaysAgo;

  /// Days-ago offset → note text, applied regardless of that day's status.
  final Map<int, String> notedDaysAgo;

  bool get isQuantityHabit => targetCount != null;
}

Future<void> seedDemoData(FirebaseFirestore firestore, String uid) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  const uuid = Uuid();
  final habitsCol = firestore.collection('users').doc(uid).collection('habits');

  final customCategoryIds = await _seedCustomCategories(firestore, uid, uuid);
  final specs = _buildSpecs(today, customCategoryIds);

  // Mood entries loosely track whether the flagship "Morning Run" habit
  // was completed that day, so the Analytics "Mood & Consistency" card has
  // a genuine (not random) correlation to show.
  final morningRun = specs.firstWhere((s) => s.name == 'Morning Run');
  final morningRunCompletedDates = _buildCheckIns(morningRun, today).entries
      .where((e) => e.value.status == CheckInStatus.completed)
      .map((e) => e.key)
      .toSet();
  await _seedMoodEntries(firestore, uid, today, morningRunCompletedDates);

  for (var i = 0; i < specs.length; i++) {
    final spec = specs[i];
    final id = uuid.v4();
    final createdAt = today.subtract(Duration(days: spec.createdDaysAgo));
    final checkIns = _buildCheckIns(spec, today);
    final statusByDate = {
      for (final e in checkIns.entries) e.key: e.value.status,
    };

    final result = StreakCalculator.compute(
      frequencyType: spec.frequencyType,
      frequencyConfig: spec.frequencyConfig,
      createdAtLocal: createdAt,
      statusByDate: statusByDate,
      today: now,
    );

    final habitDoc = habitsCol.doc(id);
    await habitDoc.set({
      'name': spec.name,
      'emoji': spec.emoji,
      'colorHex': spec.colorHex,
      'frequencyType': spec.frequencyType.toDbValue(),
      'frequencyConfig': spec.frequencyConfig.toJson(),
      'reminderTime': spec.reminderTime,
      'description': spec.description,
      'currentStreak': result.currentStreak,
      'longestStreak': result.longestStreak,
      'createdAt': Timestamp.fromDate(createdAt),
      'archivedAt': spec.archivedDaysAgo == null
          ? null
          : Timestamp.fromDate(
              today.subtract(Duration(days: spec.archivedDaysAgo!)),
            ),
      'updatedAt': Timestamp.now(),
      // Feature 6 – Sort order (insertion order = display order)
      'sortOrder': i,
      'categoryId': spec.categoryId,
      'targetCount': spec.targetCount,
      'targetUnit': spec.targetUnit,
      'isQuitHabit': spec.isQuitHabit,
    });

    // Build a map of dateStr → note for O(1) lookup
    final noteMap = <String, String>{
      for (final entry in spec.notedDaysAgo.entries)
        localDateString(today.subtract(Duration(days: entry.key))): entry.value,
    };

    var batch = firestore.batch();
    var pending = 0;
    for (final entry in checkIns.entries) {
      final dateStr = entry.key;
      batch.set(habitDoc.collection('check_ins').doc(dateStr), {
        'completed': entry.value.status == CheckInStatus.completed,
        'status': entry.value.status.toDbValue(),
        'value': entry.value.value,
        'note': noteMap[dateStr],
        'loggedAt': Timestamp.fromDate(DateTime.parse(dateStr)),
      });
      pending++;
      if (pending >= 400) {
        await batch.commit();
        batch = firestore.batch();
        pending = 0;
      }
    }
    if (pending > 0) await batch.commit();
  }
}

// ─── categories ───────────────────────────────────────────────────────────────

/// Creates a handful of custom categories (predefined ones already exist
/// as a static list and need no seeding) and returns name → id, so
/// [_buildSpecs] can assign habits to them.
Future<Map<String, String>> _seedCustomCategories(
  FirebaseFirestore firestore,
  String uid,
  Uuid uuid,
) async {
  final categoriesCol = firestore
      .collection('users')
      .doc(uid)
      .collection('categories');

  const custom = {
    'Deep Work': ('💻', '#38BDF8'),
    'Family': ('👨‍👩‍👧', '#F472B6'),
    'Personal Growth': ('🌱', '#34D399'),
  };

  final idsByName = <String, String>{};
  final batch = firestore.batch();
  for (final entry in custom.entries) {
    final id = uuid.v4();
    idsByName[entry.key] = id;
    batch.set(categoriesCol.doc(id), {
      'name': entry.key,
      'emoji': entry.value.$1,
      'colorHex': entry.value.$2,
      'createdAt': Timestamp.now(),
    });
  }
  await batch.commit();
  return idsByName;
}

// ─── mood entries ───────────────────────────────────────────────────────────

/// 60 days of mood/energy history. Mood leans higher on days
/// [goodDates] (Morning Run completed) so the correlation card has a real
/// story instead of noise.
Future<void> _seedMoodEntries(
  FirebaseFirestore firestore,
  String uid,
  DateTime today,
  Set<String> goodDates,
) async {
  final moodCol = firestore
      .collection('users')
      .doc(uid)
      .collection('mood_entries');
  var batch = firestore.batch();
  var pending = 0;
  for (var d = 0; d <= 60; d++) {
    final date = today.subtract(Duration(days: d));
    final dateStr = localDateString(date);
    final base = goodDates.contains(dateStr) ? 4 : 2;
    final wobble = d % 3 == 0 ? 1 : 0;
    final moodScore = (base + wobble).clamp(1, 5);
    final energyScore = (moodScore - (d % 2)).clamp(1, 5);
    batch.set(moodCol.doc(dateStr), {
      'moodScore': moodScore,
      'energyScore': energyScore,
      'note': d == 0 ? 'Feeling good after a solid morning run' : null,
      'loggedAt': Timestamp.fromDate(date),
    });
    pending++;
    if (pending >= 400) {
      await batch.commit();
      batch = firestore.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();
}

// ─── check-in derivation ──────────────────────────────────────────────────────

/// The single place that turns a spec's day-offset sets into an actual
/// per-date status (+ optional logged value) — shared by the write loop
/// and by the mood-correlation lookup above, so both agree on what
/// "completed" means for a quantity habit (value >= target, not just
/// "logged something").
Map<String, ({CheckInStatus status, int? value})> _buildCheckIns(
  _HabitSpec spec,
  DateTime today,
) {
  final map = <String, ({CheckInStatus status, int? value})>{};

  if (spec.isQuantityHabit) {
    for (final entry in spec.valueByDaysAgo.entries) {
      final dateStr = localDateString(
        today.subtract(Duration(days: entry.key)),
      );
      final status = spec.skipDaysAgo.contains(entry.key)
          ? CheckInStatus.skipped
          : (entry.value >= spec.targetCount!
                ? CheckInStatus.completed
                : CheckInStatus.missed);
      map[dateStr] = (status: status, value: entry.value);
    }
  } else {
    for (final d in spec.completedDaysAgo.difference(spec.skipDaysAgo)) {
      map[localDateString(today.subtract(Duration(days: d)))] = (
        status: CheckInStatus.completed,
        value: null,
      );
    }
  }

  for (final d in spec.skipDaysAgo) {
    final dateStr = localDateString(today.subtract(Duration(days: d)));
    map.putIfAbsent(
      dateStr,
      () => (status: CheckInStatus.skipped, value: null),
    );
  }

  return map;
}

// ─── helpers ────────────────────────────────────────────────────────────────

/// Every day from [mostRecentDaysAgo] up to [oldestDaysAgo], minus [except].
Set<int> _daysAgoRange(
  int oldestDaysAgo,
  int mostRecentDaysAgo, {
  Set<int> except = const {},
}) {
  final result = <int>{};
  for (var d = mostRecentDaysAgo; d <= oldestDaysAgo; d++) {
    if (!except.contains(d)) result.add(d);
  }
  return result;
}

/// Days within [fromDaysAgo] whose weekday is in [isoWeekdays].
/// [skipWeeksAgo] skips entire calendar weeks (0 = current week).
Set<int> _weekdayDaysAgo(
  DateTime today,
  int fromDaysAgo,
  Set<int> isoWeekdays, {
  Set<int> exceptDaysAgo = const {},
  Set<int> skipWeeksAgo = const {},
}) {
  final result = <int>{};
  for (var d = 0; d <= fromDaysAgo; d++) {
    if (exceptDaysAgo.contains(d)) continue;
    if (skipWeeksAgo.contains(d ~/ 7)) continue;
    final date = today.subtract(Duration(days: d));
    if (isoWeekdays.contains(date.weekday)) result.add(d);
  }
  return result;
}

/// Simulate a "mostly consistent but human" daily habit:
/// completes every day except a random-ish ~10 % miss rate
/// (deterministic via modular arithmetic so it's reproducible).
Set<int> _humanDaily(
  int fromDaysAgo, {
  int missEvery = 9,
  Set<int> extraMiss = const {},
}) {
  final result = <int>{};
  for (var d = 0; d <= fromDaysAgo; d++) {
    if (d % missEvery == 0 && d != 0) continue; // periodic miss
    if (extraMiss.contains(d)) continue;
    result.add(d);
  }
  return result;
}

/// Simulates a quantity habit's logged value per day — mostly close to or
/// above [target], with a handful of rough days at [lowDayFraction] of
/// target. Deterministic (no real randomness) so re-seeding is stable.
Map<int, int> _humanQuantity(
  int fromDaysAgo,
  int target, {
  int variance = 20,
  Set<int> lowDays = const {},
  double lowDayFraction = 0.4,
}) {
  final map = <int, int>{};
  for (var d = 0; d <= fromDaysAgo; d++) {
    if (lowDays.contains(d)) {
      map[d] = (target * lowDayFraction).round();
      continue;
    }
    final delta = ((d * 37) % (variance * 2)) - variance;
    map[d] = (target + delta).clamp(0, target + variance);
  }
  return map;
}

// ─── specs ──────────────────────────────────────────────────────────────────

List<_HabitSpec> _buildSpecs(
  DateTime today,
  Map<String, String> customCategoryIds,
) {
  final deepWork = customCategoryIds['Deep Work'];
  final family = customCategoryIds['Family'];
  final personalGrowth = customCategoryIds['Personal Growth'];

  // Gym: two travel weeks are explicit skips rather than silent misses —
  // computed here since the split (all scheduled days minus the travel
  // weeks) is clearer as two lines than as a one-off expression below.
  final gymScheduledDays = _weekdayDaysAgo(today, 120, {1, 3, 5});
  final gymTravelDays = gymScheduledDays
      .where((d) => const {8, 9}.contains(d ~/ 7))
      .toSet();
  final gymCompletedDays = gymScheduledDays.difference(gymTravelDays);

  return [
    // ── ACTIVE HABITS ──────────────────────────────────────────────────────

    // 1. Morning Run — 180-day near-perfect streak, a few sick days plus
    // two explicit "planned rest day" skips.
    _HabitSpec(
      name: 'Morning Run',
      emoji: '🏃',
      colorHex: '#B57BFF',
      frequencyType: FrequencyType.daily,
      frequencyConfig: const DailyConfig(),
      createdDaysAgo: 180,
      categoryId: 'fitness',
      reminderTime: '06:30',
      description:
          'Run at least 3 km every morning before breakfast. Track pace and distance in Nike Run Club.',
      completedDaysAgo: _daysAgoRange(
        180,
        0,
        except: {120, 119, 60, 59, 58, 30, 45, 100},
      ),
      // Distinct from the plain misses above — a deliberate "Skip" from
      // the day-action sheet, never breaks the streak.
      skipDaysAgo: const {45, 100},
      notedDaysAgo: {
        0: 'PB today — 5k in 24:12! 🔥',
        1: 'Rainy but pushed through',
        7: '7-day milestone, feeling great',
        21: 'Three weeks back on track',
        30: 'Felt sick, took the day off',
        45: 'Planned rest day — legs need it',
        100: 'Planned rest day before the race',
      },
    ),

    // 2. Read 20 Pages — 365-day habit, very consistent, a few holiday gaps
    _HabitSpec(
      name: 'Read 20 Pages',
      emoji: '📚',
      colorHex: '#C6FF00',
      frequencyType: FrequencyType.daily,
      frequencyConfig: const DailyConfig(),
      createdDaysAgo: 365,
      categoryId: 'learning',
      description:
          'Read at least 20 pages of a non-fiction book every day. No phones, no distractions.',
      completedDaysAgo: _humanDaily(
        365,
        missEvery: 11,
        extraMiss: {200, 199, 150, 100, 99, 50, 49, 48},
      ),
      notedDaysAgo: {
        0: 'Finished Atomic Habits — 10/10',
        3: 'Started Deep Work by Cal Newport',
        14: 'Chapter 7 was mind-blowing',
        30: 'Finished The Almanack of Naval Ravikant',
        60: 'Re-reading Meditations by Marcus Aurelius',
      },
    ),

    // 3. Drink Water — quantity habit, 8 glasses/day, 90 days
    _HabitSpec(
      name: 'Drink Water',
      emoji: '💧',
      colorHex: '#38BDF8',
      frequencyType: FrequencyType.daily,
      frequencyConfig: const DailyConfig(),
      createdDaysAgo: 90,
      categoryId: 'health',
      targetCount: 8,
      targetUnit: 'glasses',
      description:
          'Drink 8 glasses of water throughout the day. Use the marked bottle to track intake.',
      valueByDaysAgo: _humanQuantity(90, 8, variance: 3, lowDays: {30, 29, 15}),
      notedDaysAgo: {
        0: 'Added lemon — tastes way better',
        7: 'Skin is noticeably clearer',
        30: 'Forgot most of the day, caught up late',
      },
    ),

    // 4. Gym (Mon/Wed/Fri) — 120 days, missed some, explicit skip during travel
    _HabitSpec(
      name: 'Gym',
      emoji: '🏋️',
      colorHex: '#FF00E5',
      frequencyType: FrequencyType.weekdays,
      frequencyConfig: const WeekdaysConfig(weekdays: [1, 3, 5]),
      createdDaysAgo: 120,
      categoryId: 'fitness',
      description:
          'Strength training session — push/pull/legs split. Log sets and reps in the notebook.',
      completedDaysAgo: gymCompletedDays,
      // The two travel weeks are explicit skips, not silent gaps — the
      // streak survives them, same as a non-scheduled day would.
      skipDaysAgo: gymTravelDays,
      notedDaysAgo: {
        0: 'New PR on bench — 100kg!',
        2: 'Leg day, absolutely destroyed',
        7: 'Back from travel, felt weak but showed up',
        14: 'Increased squat weight by 5kg',
      },
    ),

    // 5. Meditate — 270-day habit, strong early streak, lapsed mid, back on track
    _HabitSpec(
      name: 'Meditate',
      emoji: '🧘',
      colorHex: '#B14EFF',
      frequencyType: FrequencyType.daily,
      frequencyConfig: const DailyConfig(),
      createdDaysAgo: 270,
      categoryId: 'mind',
      reminderTime: '07:00',
      description:
          'Sit for at least 10 minutes of mindfulness meditation. Use Insight Timer or just breathe.',
      completedDaysAgo: {
        ..._daysAgoRange(270, 150), // first 120 days: perfect
        ..._daysAgoRange(90, 0), // last 90 days: back on track
        // gap: days 91–149 = lapsed period
      },
      notedDaysAgo: {
        0: '20 min body scan, very calm',
        1: 'Tried box breathing today',
        5: 'Mind was racing but stayed with it',
        21: 'Back to 21 days — feels different this time',
        90: 'Starting fresh after the gap',
      },
    ),

    // 6. Journal — 45-day perfect streak
    _HabitSpec(
      name: 'Journal',
      emoji: '✍️',
      colorHex: '#FF4D4D',
      frequencyType: FrequencyType.daily,
      frequencyConfig: const DailyConfig(),
      createdDaysAgo: 45,
      categoryId: deepWork,
      description:
          'Write at least one page — thoughts, wins, struggles, or gratitude. No filter, just write.',
      completedDaysAgo: _daysAgoRange(45, 0),
      notedDaysAgo: {
        0: 'Wrote about the conversation with dad',
        2: 'Gratitude + 3 goals for the week',
        7: 'One week! Writing is getting easier',
        14: 'Noticed a pattern in my anxiety triggers',
        30: '30 days — this is now a real habit',
        45: 'First entry — why I want to journal',
      },
    ),

    // 7. No Sugar — 60-day habit, alternating (hard habit, realistic)
    _HabitSpec(
      name: 'No Sugar',
      emoji: '🍬',
      colorHex: '#E63950',
      frequencyType: FrequencyType.daily,
      frequencyConfig: const DailyConfig(),
      createdDaysAgo: 60,
      categoryId: 'health',
      description:
          'Zero added sugar for the day — no sweets, soda, or sugary sauces. Fruit is fine.',
      completedDaysAgo: {
        for (var d = 0; d <= 60; d++)
          if (d % 3 != 0) d, // misses every 3rd day
      },
      notedDaysAgo: {
        0: 'Craving hit hard at 3pm, drank water instead',
        1: 'Swapped dessert for fruit',
        7: 'Cravings are getting weaker',
        15: 'Birthday party — had cake, back on track tomorrow',
      },
    ),

    // 8. Call Parents (Tue + Sat) — 180 days, very consistent
    _HabitSpec(
      name: 'Call Parents',
      emoji: '📞',
      colorHex: '#B57BFF',
      frequencyType: FrequencyType.xPerWeek,
      frequencyConfig: const XPerWeekConfig(timesPerWeek: 2),
      createdDaysAgo: 180,
      categoryId: family,
      description:
          'Call mom or dad — at least 15 minutes. Ask about their week, not just share updates.',
      completedDaysAgo: _weekdayDaysAgo(
        today,
        180,
        {2, 6},
        skipWeeksAgo: {12, 20},
      ),
      notedDaysAgo: {
        0: 'Mom shared a recipe, wrote it down',
        3: 'Dad told stories about his childhood',
        7: 'Long call — 45 min, worth it',
      },
    ),

    // 9. Stretch (Mon/Wed/Fri/Sun) — 90 days, skipped 1 week
    _HabitSpec(
      name: 'Stretch',
      emoji: '🤸',
      colorHex: '#C6FF00',
      frequencyType: FrequencyType.xPerWeek,
      frequencyConfig: const XPerWeekConfig(timesPerWeek: 4),
      createdDaysAgo: 90,
      categoryId: 'fitness',
      description:
          'Full-body stretching routine — 15 minutes focusing on hips, hamstrings, and shoulders.',
      completedDaysAgo: _weekdayDaysAgo(
        today,
        90,
        {1, 3, 5, 7},
        skipWeeksAgo: {5},
      ),
      notedDaysAgo: {
        0: 'Hip flexors finally loosening up',
        7: 'Can touch toes now!',
        30: 'Back pain is almost gone',
      },
    ),

    // 10. Cold Shower — 30-day perfect streak (new habit, impressive)
    _HabitSpec(
      name: 'Cold Shower',
      emoji: '❄️',
      colorHex: '#67E8F9',
      frequencyType: FrequencyType.daily,
      frequencyConfig: const DailyConfig(),
      createdDaysAgo: 30,
      categoryId: 'health',
      description:
          'End every shower with at least 2 minutes of cold water. Build up duration over time.',
      completedDaysAgo: _daysAgoRange(30, 0),
      notedDaysAgo: {
        0: '3 minutes today, new record',
        1: 'Felt electric all morning',
        7: 'No longer dreading it',
        14: 'Energy boost is real',
        30: 'First day — lasted 30 seconds 😅',
      },
    ),

    // 11. Learn Spanish — 150 days, human-ish consistency
    _HabitSpec(
      name: 'Learn Spanish',
      emoji: '🦉',
      colorHex: '#B14EFF',
      frequencyType: FrequencyType.daily,
      frequencyConfig: const DailyConfig(),
      createdDaysAgo: 150,
      categoryId: 'learning',
      description:
          'Study Spanish for 20+ minutes — vocab, grammar, or conversation practice. Goal: B2 by year end.',
      completedDaysAgo: _humanDaily(
        150,
        missEvery: 8,
        extraMiss: {100, 99, 75, 50, 25},
      ),
      notedDaysAgo: {
        0: 'Had a 5-min conversation with a native speaker!',
        3: 'Subjunctive mood is brutal',
        14: 'Watched a Spanish show without subtitles',
        30: 'Ordered food in Spanish at a restaurant',
      },
    ),

    // 12. Sleep by 11 PM — 60 days, decent but not perfect
    _HabitSpec(
      name: 'Sleep by 11 PM',
      emoji: '🌙',
      colorHex: '#818CF8',
      frequencyType: FrequencyType.daily,
      frequencyConfig: const DailyConfig(),
      createdDaysAgo: 60,
      categoryId: 'sleep',
      reminderTime: '22:45',
      description:
          'Lights out by 11 PM — phone on charger outside the room, no screens for 30 min before.',
      completedDaysAgo: _humanDaily(
        60,
        missEvery: 7,
        extraMiss: {45, 30, 15, 7, 6},
      ),
      notedDaysAgo: {
        0: 'In bed by 10:45, read for 15 min',
        7: 'Woke up naturally before alarm',
        14: 'Sleep quality score: 92',
      },
    ),

    // 13. Gratitude List — 21-day perfect (new habit, building momentum)
    _HabitSpec(
      name: 'Gratitude List',
      emoji: '🙏',
      colorHex: '#FCD34D',
      frequencyType: FrequencyType.daily,
      frequencyConfig: const DailyConfig(),
      createdDaysAgo: 21,
      categoryId: 'mind',
      description:
          'Write 3 specific things I am grateful for today. Be specific — not just "family" but why.',
      completedDaysAgo: _daysAgoRange(21, 0),
      notedDaysAgo: {
        0: 'Grateful for: health, family, this app',
        3: 'Hard day but found 3 things anyway',
        7: 'Starting to notice beauty in small things',
        21: 'Day 1 — trying something new',
      },
    ),

    // 14. Weekly Review (Sunday) — 52 weeks of data
    _HabitSpec(
      name: 'Weekly Review',
      emoji: '📊',
      colorHex: '#34D399',
      frequencyType: FrequencyType.weekdays,
      frequencyConfig: const WeekdaysConfig(weekdays: [7]),
      createdDaysAgo: 365,
      categoryId: 'productivity',
      description:
          'Sunday review: what went well, what to improve, set 3 priorities for next week. 30 min.',
      completedDaysAgo: _weekdayDaysAgo(
        today,
        365,
        {7},
        skipWeeksAgo: {20, 35, 48},
      ),
      notedDaysAgo: {
        0: 'Q3 goals: 2/3 on track, 1 needs attention',
        7: 'Best week in months — all habits green',
        14: 'Identified time sink: social media 2h/day',
        21: 'Adjusted morning routine, feels better',
      },
    ),

    // 15. No Phone in Bed — 14-day streak (very new, building)
    _HabitSpec(
      name: 'No Phone in Bed',
      emoji: '📵',
      colorHex: '#FB923C',
      frequencyType: FrequencyType.daily,
      frequencyConfig: const DailyConfig(),
      createdDaysAgo: 14,
      categoryId: 'sleep',
      description:
          'No phone in the bedroom after 10 PM. Charger stays in the hallway. Book or nothing.',
      completedDaysAgo: _daysAgoRange(14, 0),
      notedDaysAgo: {
        0: 'Read instead — fell asleep in 10 min',
        1: 'Hardest part is not checking notifications',
        7: 'Dreams are more vivid',
        14: 'Day 1 — phone charger moved to hallway',
      },
    ),

    // 16. Push-ups — quantity habit, 50 reps/day, 60 days
    _HabitSpec(
      name: 'Push-ups',
      emoji: '💪',
      colorHex: '#FF6B00',
      frequencyType: FrequencyType.daily,
      frequencyConfig: const DailyConfig(),
      createdDaysAgo: 60,
      categoryId: 'fitness',
      targetCount: 50,
      targetUnit: 'reps',
      description: '50 push-ups a day, any split — 5x10 or straight through.',
      valueByDaysAgo: _humanQuantity(60, 50, variance: 15, lowDays: {20, 19}),
      notedDaysAgo: {
        0: 'Did them all in one set for the first time',
        20: 'Shoulder was sore, took it easy',
      },
    ),

    // 17. Steps — quantity habit, 8000 steps/day, 45 days
    _HabitSpec(
      name: 'Steps',
      emoji: '👟',
      colorHex: '#4DFFB4',
      frequencyType: FrequencyType.daily,
      frequencyConfig: const DailyConfig(),
      createdDaysAgo: 45,
      categoryId: 'health',
      targetCount: 8000,
      targetUnit: 'steps',
      description: 'Hit 8,000 steps a day — walking meetings count.',
      valueByDaysAgo: _humanQuantity(
        45,
        8000,
        variance: 2500,
        lowDays: {10, 9, 3},
      ),
      notedDaysAgo: {0: 'Long walk after dinner to close it out'},
    ),

    // 18. Quit Smoking — quit-habit mode, 60 days, two honest slips
    _HabitSpec(
      name: 'Quit Smoking',
      emoji: '🚭',
      colorHex: '#F87171',
      frequencyType: FrequencyType.daily,
      frequencyConfig: const DailyConfig(),
      createdDaysAgo: 60,
      categoryId: 'health',
      isQuitHabit: true,
      description: 'Quit for good this time — no exceptions, no "just one".',
      completedDaysAgo: _daysAgoRange(60, 0, except: {35, 12}),
      notedDaysAgo: {
        0: '60 days clean — longest ever',
        35: 'Slipped at a work event. Back on it tomorrow',
        12: 'Rough day, gave in. Not proud but not giving up either',
      },
    ),

    // 19. No Alcohol — quit-habit mode, 40 days
    _HabitSpec(
      name: 'No Alcohol',
      emoji: '🍷',
      colorHex: '#A78BFA',
      frequencyType: FrequencyType.daily,
      frequencyConfig: const DailyConfig(),
      createdDaysAgo: 40,
      categoryId: personalGrowth,
      isQuitHabit: true,
      description:
          'Sober by choice — reassessing the relationship with drinking.',
      completedDaysAgo: _daysAgoRange(40, 0, except: {20}),
      notedDaysAgo: {
        0: '40 days — sleeping so much better',
        20: 'Had a glass at a wedding. One day, not a spiral',
      },
    ),

    // ── ARCHIVED HABITS ────────────────────────────────────────────────────

    // 20. Duolingo — ran for 60 days, archived 10 days ago (replaced by Learn Spanish)
    _HabitSpec(
      name: 'Duolingo',
      emoji: '🦜',
      colorHex: '#4ADE80',
      frequencyType: FrequencyType.daily,
      frequencyConfig: const DailyConfig(),
      createdDaysAgo: 70,
      categoryId: 'learning',
      description:
          'Complete one Duolingo lesson per day to build Spanish vocabulary.',
      completedDaysAgo: _daysAgoRange(70, 11, except: {45, 44, 20}),
      archivedDaysAgo: 10,
      notedDaysAgo: {11: 'Switching to a more serious app'},
    ),

    // 21. Evening Walk — 45-day run, archived 30 days ago (merged into Morning Run)
    _HabitSpec(
      name: 'Evening Walk',
      emoji: '🚶',
      colorHex: '#F472B6',
      frequencyType: FrequencyType.daily,
      frequencyConfig: const DailyConfig(),
      createdDaysAgo: 75,
      categoryId: 'fitness',
      description: '30-minute walk after dinner to wind down and get steps in.',
      completedDaysAgo: _daysAgoRange(75, 31, except: {60, 55, 50}),
      archivedDaysAgo: 30,
      notedDaysAgo: {31: 'Merging this into morning run'},
    ),

    // 22. Vitamins — 30-day run, archived 15 days ago
    _HabitSpec(
      name: 'Vitamins',
      emoji: '💊',
      colorHex: '#A78BFA',
      frequencyType: FrequencyType.daily,
      frequencyConfig: const DailyConfig(),
      createdDaysAgo: 45,
      categoryId: 'health',
      description:
          'Take daily vitamins with breakfast — D3, magnesium, and omega-3.',
      completedDaysAgo: _daysAgoRange(45, 16),
      archivedDaysAgo: 15,
      notedDaysAgo: const {},
    ),
  ];
}
