/// The three habit-frequency modes from spec Section 5 / 5a.
///
/// Streak math branches on this — see Section 5a for the full rules per
/// type, implemented in Stage 4. This enum only carries the shape; the
/// db-string mapping lives alongside it so callers never hand-roll it.
enum FrequencyType {
  daily,
  weekdays,
  xPerWeek;

  String toDbValue() => switch (this) {
    FrequencyType.daily => 'daily',
    FrequencyType.weekdays => 'weekdays',
    FrequencyType.xPerWeek => 'x_per_week',
  };

  static FrequencyType fromDbValue(String value) => switch (value) {
    'daily' => FrequencyType.daily,
    'weekdays' => FrequencyType.weekdays,
    'x_per_week' => FrequencyType.xPerWeek,
    _ => throw ArgumentError('Unknown frequency_type: $value'),
  };
}

/// Frequency-specific config, stored as JSON in `frequency_config`.
///
/// - [daily] carries no extra config.
/// - [weekdays] lists ISO weekday numbers (1 = Monday .. 7 = Sunday).
/// - [xPerWeek] carries the weekly target count and week-start day.
sealed class FrequencyConfig {
  const FrequencyConfig();

  Map<String, dynamic> toJson();

  static FrequencyConfig fromJson(
    FrequencyType type,
    Map<String, dynamic> json,
  ) {
    switch (type) {
      case FrequencyType.daily:
        return const DailyConfig();
      case FrequencyType.weekdays:
        return WeekdaysConfig(weekdays: (json['weekdays'] as List).cast<int>());
      case FrequencyType.xPerWeek:
        return XPerWeekConfig(
          timesPerWeek: json['timesPerWeek'] as int,
          weekStartsOnMonday: json['weekStartsOnMonday'] as bool? ?? true,
        );
    }
  }
}

class DailyConfig extends FrequencyConfig {
  const DailyConfig();

  @override
  Map<String, dynamic> toJson() => const {};
}

class WeekdaysConfig extends FrequencyConfig {
  const WeekdaysConfig({required this.weekdays});

  /// ISO weekday numbers, 1 (Monday) through 7 (Sunday).
  final List<int> weekdays;

  @override
  Map<String, dynamic> toJson() => {'weekdays': weekdays};
}

class XPerWeekConfig extends FrequencyConfig {
  const XPerWeekConfig({
    required this.timesPerWeek,
    this.weekStartsOnMonday = true,
  });

  final int timesPerWeek;
  final bool weekStartsOnMonday;

  @override
  Map<String, dynamic> toJson() => {
    'timesPerWeek': timesPerWeek,
    'weekStartsOnMonday': weekStartsOnMonday,
  };
}
