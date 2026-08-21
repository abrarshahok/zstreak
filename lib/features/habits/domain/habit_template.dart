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
    this.description,
    this.weekdays,
    this.timesPerWeek,
  });

  final String emoji;
  final String name;
  final String colorHex;
  final FrequencyType frequencyType;
  final TemplateCategory category;

  /// Optional pre-filled description shown in the edit form.
  final String? description;

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
    description:
        'Write 3 pages of stream-of-consciousness first thing — no editing, just flow.',
  ),
  HabitTemplate(
    emoji: '💧',
    name: 'Drink water first thing',
    colorHex: '#00C2FF',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.morningRoutine,
    description:
        'Drink a full glass of water before coffee or breakfast to kickstart hydration.',
  ),
  HabitTemplate(
    emoji: '☀️',
    name: 'No phone for 30 min after waking',
    colorHex: '#FFB800',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.morningRoutine,
    description:
        'Keep the phone face-down for the first 30 minutes — own your morning.',
  ),
  HabitTemplate(
    emoji: '🛌',
    name: 'Make your bed',
    colorHex: '#B57BFF',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.morningRoutine,
    description:
        'Start the day with a small win — a made bed sets the tone for everything else.',
  ),
  HabitTemplate(
    emoji: '☕',
    name: 'Mindful coffee / tea',
    colorHex: '#FF6B00',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.morningRoutine,
    description:
        'Sit down, no screens — just enjoy the drink and ease into the day.',
  ),

  // ── Fitness ────────────────────────────────────────────────────────────────
  HabitTemplate(
    emoji: '🏃',
    name: 'Morning run',
    colorHex: '#FF4D4D',
    frequencyType: FrequencyType.weekdays,
    weekdays: [1, 2, 3, 4, 5],
    category: TemplateCategory.fitness,
    description:
        'Run at least 3 km before work — pace doesn\'t matter, showing up does.',
  ),
  HabitTemplate(
    emoji: '🏋️',
    name: 'Strength training',
    colorHex: '#FF4D4D',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 3,
    category: TemplateCategory.fitness,
    description:
        'Full-body or split routine — track progressive overload each session.',
  ),
  HabitTemplate(
    emoji: '🚴',
    name: 'Cycling',
    colorHex: '#9EE000',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 3,
    category: TemplateCategory.fitness,
    description:
        'Outdoor ride or stationary bike — aim for at least 30 minutes per session.',
  ),
  HabitTemplate(
    emoji: '🤸',
    name: 'Stretch / mobility',
    colorHex: '#FF4DA6',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.fitness,
    description:
        'Daily 10-minute stretch routine to improve flexibility and prevent injury.',
  ),
  HabitTemplate(
    emoji: '🚶',
    name: '10,000 steps',
    colorHex: '#9EE000',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.fitness,
    description:
        'Hit 10,000 steps every day — walk during calls, take the stairs, go outside.',
  ),
  HabitTemplate(
    emoji: '🏊',
    name: 'Swimming',
    colorHex: '#00C2FF',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 2,
    category: TemplateCategory.fitness,
    description:
        'Swim at least 30 laps — great for cardio and easy on the joints.',
  ),

  // ── Learning ───────────────────────────────────────────────────────────────
  HabitTemplate(
    emoji: '📚',
    name: 'Read 20 pages',
    colorHex: '#B57BFF',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.learning,
    description:
        'Read at least 20 pages of a non-fiction or fiction book every day.',
  ),
  HabitTemplate(
    emoji: '🗣️',
    name: 'Language practice',
    colorHex: '#00C2FF',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.learning,
    description:
        'Practice speaking, listening, or writing in the target language for 20+ minutes.',
  ),
  HabitTemplate(
    emoji: '🎓',
    name: 'Online course lesson',
    colorHex: '#FFB800',
    frequencyType: FrequencyType.weekdays,
    weekdays: [1, 2, 3, 4, 5],
    category: TemplateCategory.learning,
    description:
        'Complete at least one lesson or module from an online course on weekdays.',
  ),
  HabitTemplate(
    emoji: '✍️',
    name: 'Journaling',
    colorHex: '#B57BFF',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.learning,
    description:
        'Write about the day — what went well, what didn\'t, and what to improve.',
  ),
  HabitTemplate(
    emoji: '🧩',
    name: 'Brain puzzle / chess',
    colorHex: '#4D9FFF',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 4,
    category: TemplateCategory.learning,
    description:
        'Solve a puzzle, play chess, or do a logic challenge to keep the mind sharp.',
  ),

  // ── Mindfulness ────────────────────────────────────────────────────────────
  HabitTemplate(
    emoji: '🧘',
    name: 'Meditate 10 min',
    colorHex: '#B57BFF',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.mindfulness,
    description:
        'Sit quietly for 10 minutes — focus on breath, body scan, or guided session.',
  ),
  HabitTemplate(
    emoji: '🌿',
    name: 'Gratitude practice',
    colorHex: '#9EE000',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.mindfulness,
    description:
        'Write down 3 things you\'re grateful for — big or small, it all counts.',
  ),
  HabitTemplate(
    emoji: '🕯️',
    name: 'Evening wind-down',
    colorHex: '#FFB800',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.mindfulness,
    description:
        'Dim lights, put the phone away, and do something calming for 20 minutes before bed.',
  ),
  HabitTemplate(
    emoji: '😴',
    name: 'In bed by 10 PM',
    colorHex: '#4D9FFF',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.mindfulness,
    description:
        'Lights out by 10 PM — consistent sleep time is the foundation of good rest.',
  ),
  HabitTemplate(
    emoji: '🌙',
    name: 'No screens after 9 PM',
    colorHex: '#B57BFF',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.mindfulness,
    description:
        'Put all screens away after 9 PM to let the mind wind down naturally.',
  ),

  // ── Health ─────────────────────────────────────────────────────────────────
  HabitTemplate(
    emoji: '💊',
    name: 'Take vitamins',
    colorHex: '#FF4DA6',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.health,
    description:
        'Take daily vitamins or supplements with breakfast — consistency is key.',
  ),
  HabitTemplate(
    emoji: '🥗',
    name: 'Eat a salad',
    colorHex: '#9EE000',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 5,
    category: TemplateCategory.health,
    description:
        'Have a proper salad with greens, protein, and healthy fats at least 5 days a week.',
  ),
  HabitTemplate(
    emoji: '🚭',
    name: 'No smoking',
    colorHex: '#FF4D4D',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.health,
    description:
        'Track every smoke-free day — each one is a win worth celebrating.',
  ),
  HabitTemplate(
    emoji: '🍷',
    name: 'Alcohol-free day',
    colorHex: '#FF6B00',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 5,
    category: TemplateCategory.health,
    description:
        'Keep at least 5 alcohol-free days per week for better sleep and recovery.',
  ),
  HabitTemplate(
    emoji: '🪥',
    name: 'Floss teeth',
    colorHex: '#00C2FF',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.health,
    description:
        'Floss every night before bed — takes 2 minutes and your dentist will thank you.',
  ),

  // ── Productivity ───────────────────────────────────────────────────────────
  HabitTemplate(
    emoji: '📅',
    name: 'Plan tomorrow the night before',
    colorHex: '#FFB800',
    frequencyType: FrequencyType.weekdays,
    weekdays: [1, 2, 3, 4, 5],
    category: TemplateCategory.productivity,
    description:
        'Spend 5 minutes each evening writing tomorrow\'s top 3 priorities.',
  ),
  HabitTemplate(
    emoji: '📌',
    name: 'Weekly review',
    colorHex: '#B57BFF',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 1,
    category: TemplateCategory.productivity,
    description:
        'Review the week — what got done, what didn\'t, and what to focus on next week.',
  ),
  HabitTemplate(
    emoji: '📊',
    name: 'Check finances',
    colorHex: '#9EE000',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 1,
    category: TemplateCategory.productivity,
    description:
        'Review spending, savings, and budget once a week to stay on track.',
  ),
  HabitTemplate(
    emoji: '📞',
    name: 'Call a friend or family',
    colorHex: '#FF4DA6',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 2,
    category: TemplateCategory.productivity,
    description:
        'Make a real phone call — not a text — to someone you care about twice a week.',
  ),
  HabitTemplate(
    emoji: '🧹',
    name: 'Tidy workspace',
    colorHex: '#4D9FFF',
    frequencyType: FrequencyType.weekdays,
    weekdays: [1, 2, 3, 4, 5],
    category: TemplateCategory.productivity,
    description: 'Spend 5 minutes clearing the desk before ending the workday.',
  ),

  // ── Creativity ─────────────────────────────────────────────────────────────
  HabitTemplate(
    emoji: '🎸',
    name: 'Practice instrument',
    colorHex: '#FF6B00',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.creativity,
    description:
        'Practice for at least 20 minutes — scales, songs, or free improvisation.',
  ),
  HabitTemplate(
    emoji: '🎨',
    name: 'Sketch / draw',
    colorHex: '#FF4DA6',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 3,
    category: TemplateCategory.creativity,
    description:
        'Fill a page with sketches — anything goes, no judgment, just practice.',
  ),
  HabitTemplate(
    emoji: '📷',
    name: 'Take one photo',
    colorHex: '#4D9FFF',
    frequencyType: FrequencyType.daily,
    category: TemplateCategory.creativity,
    description:
        'Take one intentional photo every day — train your eye to see beauty.',
  ),
  HabitTemplate(
    emoji: '✏️',
    name: 'Write 500 words',
    colorHex: '#FFB800',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 4,
    category: TemplateCategory.creativity,
    description:
        'Write 500 words of anything — blog post, story, essay, or free writing.',
  ),
  HabitTemplate(
    emoji: '🪴',
    name: 'Tend to plants',
    colorHex: '#9EE000',
    frequencyType: FrequencyType.xPerWeek,
    timesPerWeek: 3,
    category: TemplateCategory.creativity,
    description:
        'Water, prune, and check on plants — a small act of care that grounds you.',
  ),
];

/// Returns the 3 featured templates shown on the empty state.
List<HabitTemplate> get kFeaturedTemplates => [
  kHabitTemplates.firstWhere((t) => t.name == 'Meditate 10 min'),
  kHabitTemplates.firstWhere((t) => t.name == 'Read 20 pages'),
  kHabitTemplates.firstWhere((t) => t.name == 'Morning run'),
];
