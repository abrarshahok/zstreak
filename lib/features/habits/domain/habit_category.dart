/// A category a habit can be grouped under — either one of the predefined
/// [kPredefinedCategories] (never persisted, just a static catalog) or a
/// user-created custom one (persisted per-backend, id generated at create
/// time). Deliberately named/scoped apart from `TemplateCategory` (the
/// unrelated, now-removed template picker's enum) to avoid confusing the
/// two — this is the user-facing, persisted grouping; that one never was.
class HabitCategory {
  const HabitCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorHex,
    this.isCustom = false,
  });

  final String id;
  final String name;
  final String emoji;
  final String colorHex;
  final bool isCustom;
}

const kPredefinedCategories = <HabitCategory>[
  HabitCategory(id: 'health', name: 'Health', emoji: '💊', colorHex: '#2F7D4F'),
  HabitCategory(
    id: 'fitness',
    name: 'Fitness',
    emoji: '🏋️',
    colorHex: '#C65A1A',
  ),
  HabitCategory(id: 'mind', name: 'Mind', emoji: '🧘', colorHex: '#5B6BC0'),
  HabitCategory(
    id: 'learning',
    name: 'Learning',
    emoji: '📚',
    colorHex: '#12746A',
  ),
  HabitCategory(
    id: 'productivity',
    name: 'Productivity',
    emoji: '✅',
    colorHex: '#B8862C',
  ),
  HabitCategory(
    id: 'creativity',
    name: 'Creativity',
    emoji: '🎨',
    colorHex: '#A0479A',
  ),
  HabitCategory(id: 'social', name: 'Social', emoji: '👥', colorHex: '#D1495B'),
  HabitCategory(
    id: 'finance',
    name: 'Finance',
    emoji: '💰',
    colorHex: '#2A9D8F',
  ),
  HabitCategory(id: 'sleep', name: 'Sleep', emoji: '🌙', colorHex: '#3B4A6B'),
  HabitCategory(id: 'other', name: 'Other', emoji: '🔖', colorHex: '#6B6660'),
];

HabitCategory? findPredefinedCategory(String id) {
  for (final c in kPredefinedCategories) {
    if (c.id == id) return c;
  }
  return null;
}
