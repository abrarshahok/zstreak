import '../domain/frequency.dart';

// ─── Template Category ────────────────────────────────────────────────────────

enum TemplateCategory {
  morningRoutine,
  fitness,
  learning,
  mindfulness,
  health,
  productivity,
  creativity;

  String get label => switch (this) {
    TemplateCategory.morningRoutine => 'Morning Routine',
    TemplateCategory.fitness => 'Fitness',
    TemplateCategory.learning => 'Learning',
    TemplateCategory.mindfulness => 'Mindfulness',
    TemplateCategory.health => 'Health',
    TemplateCategory.productivity => 'Productivity',
    TemplateCategory.creativity => 'Creativity',
  };

  String get emoji => switch (this) {
    TemplateCategory.morningRoutine => '🌅',
    TemplateCategory.fitness => '💪',
    TemplateCategory.learning => '📚',
    TemplateCategory.mindfulness => '🧘',
    TemplateCategory.health => '❤️',
    TemplateCategory.productivity => '⚡',
    TemplateCategory.creativity => '🎨',
  };
}

// ─── Habit Template ───────────────────────────────────────────────────────────

class HabitTemplate {
  const HabitTemplate({
    required this.emoji,
    required this.name,
    required this.colorHex,
    required this.frequencyType,
    required this.category,
    this.weekdays,
    this.timesPerWeek,
  });

  final String emoji;
  final String name;
  final String colorHex;
  final FrequencyType frequencyType;
  final TemplateCategory category;

  /// Only used when [frequencyType] == [FrequencyType.weekdays].
  final List<int>? weekdays;

  /// Only used when [frequencyType] == [FrequencyType.xPerWeek].
  final int? timesPerWeek;
}

// ─── Template Library ─────────────────────────────────────────────────────────

const List<HabitTemplate> kHabitTemplates = [
  // ── Morning Routine ────────────────────────────────────────────────────────
  HabitTemplate(
    emoji: '🌅',
    name: 'Morning pages',
    colorHex: '#FFB800',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.morningRoutine,
  ),
  HabitTemplate(
    emoji: '💧',
    name: 'Drink water first thing',
    colorHex: '#00C2FF',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.morningRoutine,
  ),
  HabitTemplate(
    emoji: '☀️',
    name: 'No phone for 30 min after waking',
    colorHex: '#FFB800',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.morningRoutine,
  ),
  HabitTemplate(
    emoji: '🛌',
    name: 'Make your bed',
    colorHex: '#B57BFF',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.morningRoutine,
  ),
  HabitTemplate(
    emoji: '☕',
    name: 'Mindful coffee / tea',
    colorHex: '#FF6B00',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.morningRoutine,
  ),

  // ── Fitness ────────────────────────────────────────────────────────────────
  HabitTemplate(
    emoji: '🏃',
    name: 'Morning run',
    colorHex: '#FF4D4D',
    frequencyType: FrequencyType.weekdays,
    weekdays: [1, 2, 3, 4, 5],
    category: TemplateCategory.fitness,
  ),
  HabitTemplate(
    emoji: '🏋️',
    name: 'Strength training',
    colorHex: '#FF4D4D',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 3,
    category: TemplateCategory.fitness,
  ),
  HabitTemplate(
    emoji: '🚴',
    name: 'Cycling',
    colorHex: '#9EE000',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 3,
    category: TemplateCategory.fitness,
  ),
  HabitTemplate(
    emoji: '🤸',
    name: 'Stretch / mobility',
    colorHex: '#FF4DA6',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.fitness,
  ),
  HabitTemplate(
    emoji: '🚶',
    name: '10,000 steps',
    colorHex: '#9EE000',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.fitness,
  ),
  HabitTemplate(
    emoji: '🏊',
    name: 'Swimming',
    colorHex: '#00C2FF',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 2,
    category: TemplateCategory.fitness,
  ),

  // ── Learning ───────────────────────────────────────────────────────────────
  HabitTemplate(
    emoji: '📚',
    name: 'Read 20 pages',
    colorHex: '#B57BFF',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.learning,
  ),
  HabitTemplate(
    emoji: '🗣️',
    name: 'Language practice',
    colorHex: '#00C2FF',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.learning,
  ),
  HabitTemplate(
    emoji: '🎓',
    name: 'Online course lesson',
    colorHex: '#FFB800',
    frequencyType: FrequencyType.weekdays,
    weekdays: [1, 2, 3, 4, 5],
    category: TemplateCategory.learning,
  ),
  HabitTemplate(
    emoji: '✍️',
    name: 'Journaling',
    colorHex: '#B57BFF',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.learning,
  ),
  HabitTemplate(
    emoji: '🧩',
    name: 'Brain puzzle / chess',
    colorHex: '#4D9FFF',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 4,
    category: TemplateCategory.learning,
  ),

  // ── Mindfulness ────────────────────────────────────────────────────────────
  HabitTemplate(
    emoji: '🧘',
    name: 'Meditate 10 min',
    colorHex: '#B57BFF',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.mindfulness,
  ),
  HabitTemplate(
    emoji: '🌿',
    name: 'Gratitude practice',
    colorHex: '#9EE000',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.mindfulness,
  ),
  HabitTemplate(
    emoji: '🕯️',
    name: 'Evening wind-down',
    colorHex: '#FFB800',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.mindfulness,
  ),
  HabitTemplate(
    emoji: '😴',
    name: 'In bed by 10 PM',
    colorHex: '#4D9FFF',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.mindfulness,
  ),
  HabitTemplate(
    emoji: '🌙',
    name: 'No screens after 9 PM',
    colorHex: '#B57BFF',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.mindfulness,
  ),

  // ── Health ─────────────────────────────────────────────────────────────────
  HabitTemplate(
    emoji: '💊',
    name: 'Take vitamins',
    colorHex: '#FF4DA6',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.health,
  ),
  HabitTemplate(
    emoji: '🥗',
    name: 'Eat a salad',
    colorHex: '#9EE000',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 5,
    category: TemplateCategory.health,
  ),
  HabitTemplate(
    emoji: '🚭',
    name: 'No smoking',
    colorHex: '#FF4D4D',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.health,
  ),
  HabitTemplate(
    emoji: '🍷',
    name: 'Alcohol-free day',
    colorHex: '#FF6B00',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 5,
    category: TemplateCategory.health,
  ),
  HabitTemplate(
    emoji: '🪥',
    name: 'Floss teeth',
    colorHex: '#00C2FF',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.health,
  ),

  // ── Productivity ───────────────────────────────────────────────────────────
  HabitTemplate(
    emoji: '📅',
    name: 'Plan tomorrow the night before',
    colorHex: '#FFB800',
    frequencyType: FrequencyType.weekdays,
    weekdays: [1, 2, 3, 4, 5],
    category: TemplateCategory.productivity,
  ),
  HabitTemplate(
    emoji: '📌',
    name: 'Weekly review',
    colorHex: '#B57BFF',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 1,
    category: TemplateCategory.productivity,
  ),
  HabitTemplate(
    emoji: '📊',
    name: 'Check finances',
    colorHex: '#9EE000',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 1,
    category: TemplateCategory.productivity,
  ),
  HabitTemplate(
    emoji: '📞',
    name: 'Call a friend or family',
    colorHex: '#FF4DA6',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 2,
    category: TemplateCategory.productivity,
  ),
  HabitTemplate(
    emoji: '🧹',
    name: 'Tidy workspace',
    colorHex: '#4D9FFF',
    frequencyType: FrequencyType.weekdays,
    weekdays: [1, 2, 3, 4, 5],
    category: TemplateCategory.productivity,
  ),

  // ── Creativity ─────────────────────────────────────────────────────────────
  HabitTemplate(
    emoji: '🎸',
    name: 'Practice instrument',
    colorHex: '#FF6B00',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.creativity,
  ),
  HabitTemplate(
    emoji: '🎨',
    name: 'Sketch / draw',
    colorHex: '#FF4DA6',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 3,
    category: TemplateCategory.creativity,
  ),
  HabitTemplate(
    emoji: '📷',
    name: 'Take one photo',
    colorHex: '#4D9FFF',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.creativity,
  ),
  HabitTemplate(
    emoji: '✏️',
    name: 'Write 500 words',
    colorHex: '#FFB800',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 4,
    category: TemplateCategory.creativity,
  ),
  HabitTemplate(
    emoji: '🪴',
    name: 'Tend to plants',
    colorHex: '#9EE000',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 3,
    category: TemplateCategory.creativity,
  ),
];

/// Returns the 3 featured templates shown on the empty state.
List<HabitTemplate> get kFeaturedTemplates => [
  kHabitTemplates.firstWhere((t) => t.name == 'Meditate 10 min'),
  kHabitTemplates.firstWhere((t) => t.name == 'Read 20 pages'),
  kHabitTemplates.firstWhere((t) => t.name == 'Morning run'),
];
