// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $HabitsTable extends Habits with TableInfo<$HabitsTable, HabitRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
    'emoji',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _frequencyTypeMeta = const VerificationMeta(
    'frequencyType',
  );
  @override
  late final GeneratedColumn<String> frequencyType = GeneratedColumn<String>(
    'frequency_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _frequencyConfigMeta = const VerificationMeta(
    'frequencyConfig',
  );
  @override
  late final GeneratedColumn<String> frequencyConfig = GeneratedColumn<String>(
    'frequency_config',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reminderTimeMeta = const VerificationMeta(
    'reminderTime',
  );
  @override
  late final GeneratedColumn<String> reminderTime = GeneratedColumn<String>(
    'reminder_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentStreakMeta = const VerificationMeta(
    'currentStreak',
  );
  @override
  late final GeneratedColumn<int> currentStreak = GeneratedColumn<int>(
    'current_streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _longestStreakMeta = const VerificationMeta(
    'longestStreak',
  );
  @override
  late final GeneratedColumn<int> longestStreak = GeneratedColumn<int>(
    'longest_streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _streakFreezesMeta = const VerificationMeta(
    'streakFreezes',
  );
  @override
  late final GeneratedColumn<int> streakFreezes = GeneratedColumn<int>(
    'streak_freezes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _frozenDatesMeta = const VerificationMeta(
    'frozenDates',
  );
  @override
  late final GeneratedColumn<String> frozenDates = GeneratedColumn<String>(
    'frozen_dates',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    emoji,
    colorHex,
    frequencyType,
    frequencyConfig,
    reminderTime,
    description,
    currentStreak,
    longestStreak,
    createdAt,
    archivedAt,
    updatedAt,
    streakFreezes,
    frozenDates,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habits';
  @override
  VerificationContext validateIntegrity(
    Insertable<HabitRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('emoji')) {
      context.handle(
        _emojiMeta,
        emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta),
      );
    } else if (isInserting) {
      context.missing(_emojiMeta);
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    } else if (isInserting) {
      context.missing(_colorHexMeta);
    }
    if (data.containsKey('frequency_type')) {
      context.handle(
        _frequencyTypeMeta,
        frequencyType.isAcceptableOrUnknown(
          data['frequency_type']!,
          _frequencyTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_frequencyTypeMeta);
    }
    if (data.containsKey('frequency_config')) {
      context.handle(
        _frequencyConfigMeta,
        frequencyConfig.isAcceptableOrUnknown(
          data['frequency_config']!,
          _frequencyConfigMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_frequencyConfigMeta);
    }
    if (data.containsKey('reminder_time')) {
      context.handle(
        _reminderTimeMeta,
        reminderTime.isAcceptableOrUnknown(
          data['reminder_time']!,
          _reminderTimeMeta,
        ),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('current_streak')) {
      context.handle(
        _currentStreakMeta,
        currentStreak.isAcceptableOrUnknown(
          data['current_streak']!,
          _currentStreakMeta,
        ),
      );
    }
    if (data.containsKey('longest_streak')) {
      context.handle(
        _longestStreakMeta,
        longestStreak.isAcceptableOrUnknown(
          data['longest_streak']!,
          _longestStreakMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('streak_freezes')) {
      context.handle(
        _streakFreezesMeta,
        streakFreezes.isAcceptableOrUnknown(
          data['streak_freezes']!,
          _streakFreezesMeta,
        ),
      );
    }
    if (data.containsKey('frozen_dates')) {
      context.handle(
        _frozenDatesMeta,
        frozenDates.isAcceptableOrUnknown(
          data['frozen_dates']!,
          _frozenDatesMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HabitRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      emoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emoji'],
      )!,
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      )!,
      frequencyType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frequency_type'],
      )!,
      frequencyConfig: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frequency_config'],
      )!,
      reminderTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_time'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      currentStreak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_streak'],
      )!,
      longestStreak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}longest_streak'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      streakFreezes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}streak_freezes'],
      )!,
      frozenDates: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frozen_dates'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $HabitsTable createAlias(String alias) {
    return $HabitsTable(attachedDatabase, alias);
  }
}

class HabitRow extends DataClass implements Insertable<HabitRow> {
  final String id;
  final String name;
  final String emoji;
  final String colorHex;
  final String frequencyType;
  final String frequencyConfig;
  final String? reminderTime;

  /// Optional free-text description of what the user plans to track.
  final String? description;
  final int currentStreak;
  final int longestStreak;
  final DateTime createdAt;
  final DateTime? archivedAt;
  final DateTime updatedAt;

  /// Feature 1 – Streak Freeze: number of available freeze tokens.
  /// Defaults to 1 so new habits start with one free freeze.
  final int streakFreezes;

  /// Feature 1 – Streak Freeze: JSON-encoded list of "YYYY-MM-DD" strings
  /// for days that were frozen (missed but protected from streak reset).
  final String? frozenDates;

  /// Feature 6 – Drag-to-reorder: lower values appear first in the list.
  final int sortOrder;
  const HabitRow({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorHex,
    required this.frequencyType,
    required this.frequencyConfig,
    this.reminderTime,
    this.description,
    required this.currentStreak,
    required this.longestStreak,
    required this.createdAt,
    this.archivedAt,
    required this.updatedAt,
    required this.streakFreezes,
    this.frozenDates,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['emoji'] = Variable<String>(emoji);
    map['color_hex'] = Variable<String>(colorHex);
    map['frequency_type'] = Variable<String>(frequencyType);
    map['frequency_config'] = Variable<String>(frequencyConfig);
    if (!nullToAbsent || reminderTime != null) {
      map['reminder_time'] = Variable<String>(reminderTime);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['current_streak'] = Variable<int>(currentStreak);
    map['longest_streak'] = Variable<int>(longestStreak);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['streak_freezes'] = Variable<int>(streakFreezes);
    if (!nullToAbsent || frozenDates != null) {
      map['frozen_dates'] = Variable<String>(frozenDates);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  HabitsCompanion toCompanion(bool nullToAbsent) {
    return HabitsCompanion(
      id: Value(id),
      name: Value(name),
      emoji: Value(emoji),
      colorHex: Value(colorHex),
      frequencyType: Value(frequencyType),
      frequencyConfig: Value(frequencyConfig),
      reminderTime: reminderTime == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderTime),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      currentStreak: Value(currentStreak),
      longestStreak: Value(longestStreak),
      createdAt: Value(createdAt),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      updatedAt: Value(updatedAt),
      streakFreezes: Value(streakFreezes),
      frozenDates: frozenDates == null && nullToAbsent
          ? const Value.absent()
          : Value(frozenDates),
      sortOrder: Value(sortOrder),
    );
  }

  factory HabitRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HabitRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      emoji: serializer.fromJson<String>(json['emoji']),
      colorHex: serializer.fromJson<String>(json['colorHex']),
      frequencyType: serializer.fromJson<String>(json['frequencyType']),
      frequencyConfig: serializer.fromJson<String>(json['frequencyConfig']),
      reminderTime: serializer.fromJson<String?>(json['reminderTime']),
      description: serializer.fromJson<String?>(json['description']),
      currentStreak: serializer.fromJson<int>(json['currentStreak']),
      longestStreak: serializer.fromJson<int>(json['longestStreak']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      streakFreezes: serializer.fromJson<int>(json['streakFreezes']),
      frozenDates: serializer.fromJson<String?>(json['frozenDates']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'emoji': serializer.toJson<String>(emoji),
      'colorHex': serializer.toJson<String>(colorHex),
      'frequencyType': serializer.toJson<String>(frequencyType),
      'frequencyConfig': serializer.toJson<String>(frequencyConfig),
      'reminderTime': serializer.toJson<String?>(reminderTime),
      'description': serializer.toJson<String?>(description),
      'currentStreak': serializer.toJson<int>(currentStreak),
      'longestStreak': serializer.toJson<int>(longestStreak),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'streakFreezes': serializer.toJson<int>(streakFreezes),
      'frozenDates': serializer.toJson<String?>(frozenDates),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  HabitRow copyWith({
    String? id,
    String? name,
    String? emoji,
    String? colorHex,
    String? frequencyType,
    String? frequencyConfig,
    Value<String?> reminderTime = const Value.absent(),
    Value<String?> description = const Value.absent(),
    int? currentStreak,
    int? longestStreak,
    DateTime? createdAt,
    Value<DateTime?> archivedAt = const Value.absent(),
    DateTime? updatedAt,
    int? streakFreezes,
    Value<String?> frozenDates = const Value.absent(),
    int? sortOrder,
  }) => HabitRow(
    id: id ?? this.id,
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    colorHex: colorHex ?? this.colorHex,
    frequencyType: frequencyType ?? this.frequencyType,
    frequencyConfig: frequencyConfig ?? this.frequencyConfig,
    reminderTime: reminderTime.present ? reminderTime.value : this.reminderTime,
    description: description.present ? description.value : this.description,
    currentStreak: currentStreak ?? this.currentStreak,
    longestStreak: longestStreak ?? this.longestStreak,
    createdAt: createdAt ?? this.createdAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    streakFreezes: streakFreezes ?? this.streakFreezes,
    frozenDates: frozenDates.present ? frozenDates.value : this.frozenDates,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  HabitRow copyWithCompanion(HabitsCompanion data) {
    return HabitRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      frequencyType: data.frequencyType.present
          ? data.frequencyType.value
          : this.frequencyType,
      frequencyConfig: data.frequencyConfig.present
          ? data.frequencyConfig.value
          : this.frequencyConfig,
      reminderTime: data.reminderTime.present
          ? data.reminderTime.value
          : this.reminderTime,
      description: data.description.present
          ? data.description.value
          : this.description,
      currentStreak: data.currentStreak.present
          ? data.currentStreak.value
          : this.currentStreak,
      longestStreak: data.longestStreak.present
          ? data.longestStreak.value
          : this.longestStreak,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      streakFreezes: data.streakFreezes.present
          ? data.streakFreezes.value
          : this.streakFreezes,
      frozenDates: data.frozenDates.present
          ? data.frozenDates.value
          : this.frozenDates,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HabitRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('emoji: $emoji, ')
          ..write('colorHex: $colorHex, ')
          ..write('frequencyType: $frequencyType, ')
          ..write('frequencyConfig: $frequencyConfig, ')
          ..write('reminderTime: $reminderTime, ')
          ..write('description: $description, ')
          ..write('currentStreak: $currentStreak, ')
          ..write('longestStreak: $longestStreak, ')
          ..write('createdAt: $createdAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('streakFreezes: $streakFreezes, ')
          ..write('frozenDates: $frozenDates, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    emoji,
    colorHex,
    frequencyType,
    frequencyConfig,
    reminderTime,
    description,
    currentStreak,
    longestStreak,
    createdAt,
    archivedAt,
    updatedAt,
    streakFreezes,
    frozenDates,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HabitRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.emoji == this.emoji &&
          other.colorHex == this.colorHex &&
          other.frequencyType == this.frequencyType &&
          other.frequencyConfig == this.frequencyConfig &&
          other.reminderTime == this.reminderTime &&
          other.description == this.description &&
          other.currentStreak == this.currentStreak &&
          other.longestStreak == this.longestStreak &&
          other.createdAt == this.createdAt &&
          other.archivedAt == this.archivedAt &&
          other.updatedAt == this.updatedAt &&
          other.streakFreezes == this.streakFreezes &&
          other.frozenDates == this.frozenDates &&
          other.sortOrder == this.sortOrder);
}

class HabitsCompanion extends UpdateCompanion<HabitRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> emoji;
  final Value<String> colorHex;
  final Value<String> frequencyType;
  final Value<String> frequencyConfig;
  final Value<String?> reminderTime;
  final Value<String?> description;
  final Value<int> currentStreak;
  final Value<int> longestStreak;
  final Value<DateTime> createdAt;
  final Value<DateTime?> archivedAt;
  final Value<DateTime> updatedAt;
  final Value<int> streakFreezes;
  final Value<String?> frozenDates;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const HabitsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.emoji = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.frequencyType = const Value.absent(),
    this.frequencyConfig = const Value.absent(),
    this.reminderTime = const Value.absent(),
    this.description = const Value.absent(),
    this.currentStreak = const Value.absent(),
    this.longestStreak = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.streakFreezes = const Value.absent(),
    this.frozenDates = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HabitsCompanion.insert({
    required String id,
    required String name,
    required String emoji,
    required String colorHex,
    required String frequencyType,
    required String frequencyConfig,
    this.reminderTime = const Value.absent(),
    this.description = const Value.absent(),
    this.currentStreak = const Value.absent(),
    this.longestStreak = const Value.absent(),
    required DateTime createdAt,
    this.archivedAt = const Value.absent(),
    required DateTime updatedAt,
    this.streakFreezes = const Value.absent(),
    this.frozenDates = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       emoji = Value(emoji),
       colorHex = Value(colorHex),
       frequencyType = Value(frequencyType),
       frequencyConfig = Value(frequencyConfig),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<HabitRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? emoji,
    Expression<String>? colorHex,
    Expression<String>? frequencyType,
    Expression<String>? frequencyConfig,
    Expression<String>? reminderTime,
    Expression<String>? description,
    Expression<int>? currentStreak,
    Expression<int>? longestStreak,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? streakFreezes,
    Expression<String>? frozenDates,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (emoji != null) 'emoji': emoji,
      if (colorHex != null) 'color_hex': colorHex,
      if (frequencyType != null) 'frequency_type': frequencyType,
      if (frequencyConfig != null) 'frequency_config': frequencyConfig,
      if (reminderTime != null) 'reminder_time': reminderTime,
      if (description != null) 'description': description,
      if (currentStreak != null) 'current_streak': currentStreak,
      if (longestStreak != null) 'longest_streak': longestStreak,
      if (createdAt != null) 'created_at': createdAt,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (streakFreezes != null) 'streak_freezes': streakFreezes,
      if (frozenDates != null) 'frozen_dates': frozenDates,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HabitsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? emoji,
    Value<String>? colorHex,
    Value<String>? frequencyType,
    Value<String>? frequencyConfig,
    Value<String?>? reminderTime,
    Value<String?>? description,
    Value<int>? currentStreak,
    Value<int>? longestStreak,
    Value<DateTime>? createdAt,
    Value<DateTime?>? archivedAt,
    Value<DateTime>? updatedAt,
    Value<int>? streakFreezes,
    Value<String?>? frozenDates,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return HabitsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      colorHex: colorHex ?? this.colorHex,
      frequencyType: frequencyType ?? this.frequencyType,
      frequencyConfig: frequencyConfig ?? this.frequencyConfig,
      reminderTime: reminderTime ?? this.reminderTime,
      description: description ?? this.description,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      createdAt: createdAt ?? this.createdAt,
      archivedAt: archivedAt ?? this.archivedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      streakFreezes: streakFreezes ?? this.streakFreezes,
      frozenDates: frozenDates ?? this.frozenDates,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (frequencyType.present) {
      map['frequency_type'] = Variable<String>(frequencyType.value);
    }
    if (frequencyConfig.present) {
      map['frequency_config'] = Variable<String>(frequencyConfig.value);
    }
    if (reminderTime.present) {
      map['reminder_time'] = Variable<String>(reminderTime.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (currentStreak.present) {
      map['current_streak'] = Variable<int>(currentStreak.value);
    }
    if (longestStreak.present) {
      map['longest_streak'] = Variable<int>(longestStreak.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (streakFreezes.present) {
      map['streak_freezes'] = Variable<int>(streakFreezes.value);
    }
    if (frozenDates.present) {
      map['frozen_dates'] = Variable<String>(frozenDates.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('emoji: $emoji, ')
          ..write('colorHex: $colorHex, ')
          ..write('frequencyType: $frequencyType, ')
          ..write('frequencyConfig: $frequencyConfig, ')
          ..write('reminderTime: $reminderTime, ')
          ..write('description: $description, ')
          ..write('currentStreak: $currentStreak, ')
          ..write('longestStreak: $longestStreak, ')
          ..write('createdAt: $createdAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('streakFreezes: $streakFreezes, ')
          ..write('frozenDates: $frozenDates, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CheckInsTable extends CheckIns
    with TableInfo<$CheckInsTable, CheckInRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CheckInsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _habitIdMeta = const VerificationMeta(
    'habitId',
  );
  @override
  late final GeneratedColumn<String> habitId = GeneratedColumn<String>(
    'habit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES habits (id)',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _loggedAtMeta = const VerificationMeta(
    'loggedAt',
  );
  @override
  late final GeneratedColumn<DateTime> loggedAt = GeneratedColumn<DateTime>(
    'logged_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    habitId,
    date,
    completed,
    note,
    loggedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'check_ins';
  @override
  VerificationContext validateIntegrity(
    Insertable<CheckInRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('habit_id')) {
      context.handle(
        _habitIdMeta,
        habitId.isAcceptableOrUnknown(data['habit_id']!, _habitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_habitIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('logged_at')) {
      context.handle(
        _loggedAtMeta,
        loggedAt.isAcceptableOrUnknown(data['logged_at']!, _loggedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_loggedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {habitId, date},
  ];
  @override
  CheckInRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CheckInRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      habitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}habit_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      loggedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}logged_at'],
      )!,
    );
  }

  @override
  $CheckInsTable createAlias(String alias) {
    return $CheckInsTable(attachedDatabase, alias);
  }
}

class CheckInRow extends DataClass implements Insertable<CheckInRow> {
  final String id;
  final String habitId;

  /// Local calendar date "YYYY-MM-DD" — the check-in's identity, not a
  /// UTC timestamp (spec Section 2).
  final String date;
  final bool completed;
  final String? note;
  final DateTime loggedAt;
  const CheckInRow({
    required this.id,
    required this.habitId,
    required this.date,
    required this.completed,
    this.note,
    required this.loggedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['habit_id'] = Variable<String>(habitId);
    map['date'] = Variable<String>(date);
    map['completed'] = Variable<bool>(completed);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['logged_at'] = Variable<DateTime>(loggedAt);
    return map;
  }

  CheckInsCompanion toCompanion(bool nullToAbsent) {
    return CheckInsCompanion(
      id: Value(id),
      habitId: Value(habitId),
      date: Value(date),
      completed: Value(completed),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      loggedAt: Value(loggedAt),
    );
  }

  factory CheckInRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CheckInRow(
      id: serializer.fromJson<String>(json['id']),
      habitId: serializer.fromJson<String>(json['habitId']),
      date: serializer.fromJson<String>(json['date']),
      completed: serializer.fromJson<bool>(json['completed']),
      note: serializer.fromJson<String?>(json['note']),
      loggedAt: serializer.fromJson<DateTime>(json['loggedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'habitId': serializer.toJson<String>(habitId),
      'date': serializer.toJson<String>(date),
      'completed': serializer.toJson<bool>(completed),
      'note': serializer.toJson<String?>(note),
      'loggedAt': serializer.toJson<DateTime>(loggedAt),
    };
  }

  CheckInRow copyWith({
    String? id,
    String? habitId,
    String? date,
    bool? completed,
    Value<String?> note = const Value.absent(),
    DateTime? loggedAt,
  }) => CheckInRow(
    id: id ?? this.id,
    habitId: habitId ?? this.habitId,
    date: date ?? this.date,
    completed: completed ?? this.completed,
    note: note.present ? note.value : this.note,
    loggedAt: loggedAt ?? this.loggedAt,
  );
  CheckInRow copyWithCompanion(CheckInsCompanion data) {
    return CheckInRow(
      id: data.id.present ? data.id.value : this.id,
      habitId: data.habitId.present ? data.habitId.value : this.habitId,
      date: data.date.present ? data.date.value : this.date,
      completed: data.completed.present ? data.completed.value : this.completed,
      note: data.note.present ? data.note.value : this.note,
      loggedAt: data.loggedAt.present ? data.loggedAt.value : this.loggedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CheckInRow(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('date: $date, ')
          ..write('completed: $completed, ')
          ..write('note: $note, ')
          ..write('loggedAt: $loggedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, habitId, date, completed, note, loggedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CheckInRow &&
          other.id == this.id &&
          other.habitId == this.habitId &&
          other.date == this.date &&
          other.completed == this.completed &&
          other.note == this.note &&
          other.loggedAt == this.loggedAt);
}

class CheckInsCompanion extends UpdateCompanion<CheckInRow> {
  final Value<String> id;
  final Value<String> habitId;
  final Value<String> date;
  final Value<bool> completed;
  final Value<String?> note;
  final Value<DateTime> loggedAt;
  final Value<int> rowid;
  const CheckInsCompanion({
    this.id = const Value.absent(),
    this.habitId = const Value.absent(),
    this.date = const Value.absent(),
    this.completed = const Value.absent(),
    this.note = const Value.absent(),
    this.loggedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CheckInsCompanion.insert({
    required String id,
    required String habitId,
    required String date,
    this.completed = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime loggedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       habitId = Value(habitId),
       date = Value(date),
       loggedAt = Value(loggedAt);
  static Insertable<CheckInRow> custom({
    Expression<String>? id,
    Expression<String>? habitId,
    Expression<String>? date,
    Expression<bool>? completed,
    Expression<String>? note,
    Expression<DateTime>? loggedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (habitId != null) 'habit_id': habitId,
      if (date != null) 'date': date,
      if (completed != null) 'completed': completed,
      if (note != null) 'note': note,
      if (loggedAt != null) 'logged_at': loggedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CheckInsCompanion copyWith({
    Value<String>? id,
    Value<String>? habitId,
    Value<String>? date,
    Value<bool>? completed,
    Value<String?>? note,
    Value<DateTime>? loggedAt,
    Value<int>? rowid,
  }) {
    return CheckInsCompanion(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      date: date ?? this.date,
      completed: completed ?? this.completed,
      note: note ?? this.note,
      loggedAt: loggedAt ?? this.loggedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (habitId.present) {
      map['habit_id'] = Variable<String>(habitId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (loggedAt.present) {
      map['logged_at'] = Variable<DateTime>(loggedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CheckInsCompanion(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('date: $date, ')
          ..write('completed: $completed, ')
          ..write('note: $note, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GuestMetaTable extends GuestMeta
    with TableInfo<$GuestMetaTable, GuestMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GuestMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _guestStartedAtMeta = const VerificationMeta(
    'guestStartedAt',
  );
  @override
  late final GeneratedColumn<DateTime> guestStartedAt =
      GeneratedColumn<DateTime>(
        'guest_started_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _firebaseAnonymousUidMeta =
      const VerificationMeta('firebaseAnonymousUid');
  @override
  late final GeneratedColumn<String> firebaseAnonymousUid =
      GeneratedColumn<String>(
        'firebase_anonymous_uid',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _migrationStatusMeta = const VerificationMeta(
    'migrationStatus',
  );
  @override
  late final GeneratedColumn<String> migrationStatus = GeneratedColumn<String>(
    'migration_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('not_started'),
  );
  static const VerificationMeta _wasMergeMeta = const VerificationMeta(
    'wasMerge',
  );
  @override
  late final GeneratedColumn<bool> wasMerge = GeneratedColumn<bool>(
    'was_merge',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("was_merge" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    guestStartedAt,
    firebaseAnonymousUid,
    migrationStatus,
    wasMerge,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'guest_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<GuestMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('guest_started_at')) {
      context.handle(
        _guestStartedAtMeta,
        guestStartedAt.isAcceptableOrUnknown(
          data['guest_started_at']!,
          _guestStartedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_guestStartedAtMeta);
    }
    if (data.containsKey('firebase_anonymous_uid')) {
      context.handle(
        _firebaseAnonymousUidMeta,
        firebaseAnonymousUid.isAcceptableOrUnknown(
          data['firebase_anonymous_uid']!,
          _firebaseAnonymousUidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firebaseAnonymousUidMeta);
    }
    if (data.containsKey('migration_status')) {
      context.handle(
        _migrationStatusMeta,
        migrationStatus.isAcceptableOrUnknown(
          data['migration_status']!,
          _migrationStatusMeta,
        ),
      );
    }
    if (data.containsKey('was_merge')) {
      context.handle(
        _wasMergeMeta,
        wasMerge.isAcceptableOrUnknown(data['was_merge']!, _wasMergeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GuestMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GuestMetaRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      guestStartedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}guest_started_at'],
      )!,
      firebaseAnonymousUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firebase_anonymous_uid'],
      )!,
      migrationStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}migration_status'],
      )!,
      wasMerge: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}was_merge'],
      )!,
    );
  }

  @override
  $GuestMetaTable createAlias(String alias) {
    return $GuestMetaTable(attachedDatabase, alias);
  }
}

class GuestMetaRow extends DataClass implements Insertable<GuestMetaRow> {
  final int id;
  final DateTime guestStartedAt;
  final String firebaseAnonymousUid;
  final String migrationStatus;

  /// Persisted so a resumed migration (Stage 6, after an app close
  /// mid-migration) knows whether the free-tier archive-on-import rule
  /// applies, without the caller having to remember it across a restart.
  final bool wasMerge;
  const GuestMetaRow({
    required this.id,
    required this.guestStartedAt,
    required this.firebaseAnonymousUid,
    required this.migrationStatus,
    required this.wasMerge,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['guest_started_at'] = Variable<DateTime>(guestStartedAt);
    map['firebase_anonymous_uid'] = Variable<String>(firebaseAnonymousUid);
    map['migration_status'] = Variable<String>(migrationStatus);
    map['was_merge'] = Variable<bool>(wasMerge);
    return map;
  }

  GuestMetaCompanion toCompanion(bool nullToAbsent) {
    return GuestMetaCompanion(
      id: Value(id),
      guestStartedAt: Value(guestStartedAt),
      firebaseAnonymousUid: Value(firebaseAnonymousUid),
      migrationStatus: Value(migrationStatus),
      wasMerge: Value(wasMerge),
    );
  }

  factory GuestMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GuestMetaRow(
      id: serializer.fromJson<int>(json['id']),
      guestStartedAt: serializer.fromJson<DateTime>(json['guestStartedAt']),
      firebaseAnonymousUid: serializer.fromJson<String>(
        json['firebaseAnonymousUid'],
      ),
      migrationStatus: serializer.fromJson<String>(json['migrationStatus']),
      wasMerge: serializer.fromJson<bool>(json['wasMerge']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'guestStartedAt': serializer.toJson<DateTime>(guestStartedAt),
      'firebaseAnonymousUid': serializer.toJson<String>(firebaseAnonymousUid),
      'migrationStatus': serializer.toJson<String>(migrationStatus),
      'wasMerge': serializer.toJson<bool>(wasMerge),
    };
  }

  GuestMetaRow copyWith({
    int? id,
    DateTime? guestStartedAt,
    String? firebaseAnonymousUid,
    String? migrationStatus,
    bool? wasMerge,
  }) => GuestMetaRow(
    id: id ?? this.id,
    guestStartedAt: guestStartedAt ?? this.guestStartedAt,
    firebaseAnonymousUid: firebaseAnonymousUid ?? this.firebaseAnonymousUid,
    migrationStatus: migrationStatus ?? this.migrationStatus,
    wasMerge: wasMerge ?? this.wasMerge,
  );
  GuestMetaRow copyWithCompanion(GuestMetaCompanion data) {
    return GuestMetaRow(
      id: data.id.present ? data.id.value : this.id,
      guestStartedAt: data.guestStartedAt.present
          ? data.guestStartedAt.value
          : this.guestStartedAt,
      firebaseAnonymousUid: data.firebaseAnonymousUid.present
          ? data.firebaseAnonymousUid.value
          : this.firebaseAnonymousUid,
      migrationStatus: data.migrationStatus.present
          ? data.migrationStatus.value
          : this.migrationStatus,
      wasMerge: data.wasMerge.present ? data.wasMerge.value : this.wasMerge,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GuestMetaRow(')
          ..write('id: $id, ')
          ..write('guestStartedAt: $guestStartedAt, ')
          ..write('firebaseAnonymousUid: $firebaseAnonymousUid, ')
          ..write('migrationStatus: $migrationStatus, ')
          ..write('wasMerge: $wasMerge')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    guestStartedAt,
    firebaseAnonymousUid,
    migrationStatus,
    wasMerge,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GuestMetaRow &&
          other.id == this.id &&
          other.guestStartedAt == this.guestStartedAt &&
          other.firebaseAnonymousUid == this.firebaseAnonymousUid &&
          other.migrationStatus == this.migrationStatus &&
          other.wasMerge == this.wasMerge);
}

class GuestMetaCompanion extends UpdateCompanion<GuestMetaRow> {
  final Value<int> id;
  final Value<DateTime> guestStartedAt;
  final Value<String> firebaseAnonymousUid;
  final Value<String> migrationStatus;
  final Value<bool> wasMerge;
  const GuestMetaCompanion({
    this.id = const Value.absent(),
    this.guestStartedAt = const Value.absent(),
    this.firebaseAnonymousUid = const Value.absent(),
    this.migrationStatus = const Value.absent(),
    this.wasMerge = const Value.absent(),
  });
  GuestMetaCompanion.insert({
    this.id = const Value.absent(),
    required DateTime guestStartedAt,
    required String firebaseAnonymousUid,
    this.migrationStatus = const Value.absent(),
    this.wasMerge = const Value.absent(),
  }) : guestStartedAt = Value(guestStartedAt),
       firebaseAnonymousUid = Value(firebaseAnonymousUid);
  static Insertable<GuestMetaRow> custom({
    Expression<int>? id,
    Expression<DateTime>? guestStartedAt,
    Expression<String>? firebaseAnonymousUid,
    Expression<String>? migrationStatus,
    Expression<bool>? wasMerge,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (guestStartedAt != null) 'guest_started_at': guestStartedAt,
      if (firebaseAnonymousUid != null)
        'firebase_anonymous_uid': firebaseAnonymousUid,
      if (migrationStatus != null) 'migration_status': migrationStatus,
      if (wasMerge != null) 'was_merge': wasMerge,
    });
  }

  GuestMetaCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? guestStartedAt,
    Value<String>? firebaseAnonymousUid,
    Value<String>? migrationStatus,
    Value<bool>? wasMerge,
  }) {
    return GuestMetaCompanion(
      id: id ?? this.id,
      guestStartedAt: guestStartedAt ?? this.guestStartedAt,
      firebaseAnonymousUid: firebaseAnonymousUid ?? this.firebaseAnonymousUid,
      migrationStatus: migrationStatus ?? this.migrationStatus,
      wasMerge: wasMerge ?? this.wasMerge,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (guestStartedAt.present) {
      map['guest_started_at'] = Variable<DateTime>(guestStartedAt.value);
    }
    if (firebaseAnonymousUid.present) {
      map['firebase_anonymous_uid'] = Variable<String>(
        firebaseAnonymousUid.value,
      );
    }
    if (migrationStatus.present) {
      map['migration_status'] = Variable<String>(migrationStatus.value);
    }
    if (wasMerge.present) {
      map['was_merge'] = Variable<bool>(wasMerge.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GuestMetaCompanion(')
          ..write('id: $id, ')
          ..write('guestStartedAt: $guestStartedAt, ')
          ..write('firebaseAnonymousUid: $firebaseAnonymousUid, ')
          ..write('migrationStatus: $migrationStatus, ')
          ..write('wasMerge: $wasMerge')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $HabitsTable habits = $HabitsTable(this);
  late final $CheckInsTable checkIns = $CheckInsTable(this);
  late final $GuestMetaTable guestMeta = $GuestMetaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    habits,
    checkIns,
    guestMeta,
  ];
}

typedef $$HabitsTableCreateCompanionBuilder =
    HabitsCompanion Function({
      required String id,
      required String name,
      required String emoji,
      required String colorHex,
      required String frequencyType,
      required String frequencyConfig,
      Value<String?> reminderTime,
      Value<String?> description,
      Value<int> currentStreak,
      Value<int> longestStreak,
      required DateTime createdAt,
      Value<DateTime?> archivedAt,
      required DateTime updatedAt,
      Value<int> streakFreezes,
      Value<String?> frozenDates,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$HabitsTableUpdateCompanionBuilder =
    HabitsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> emoji,
      Value<String> colorHex,
      Value<String> frequencyType,
      Value<String> frequencyConfig,
      Value<String?> reminderTime,
      Value<String?> description,
      Value<int> currentStreak,
      Value<int> longestStreak,
      Value<DateTime> createdAt,
      Value<DateTime?> archivedAt,
      Value<DateTime> updatedAt,
      Value<int> streakFreezes,
      Value<String?> frozenDates,
      Value<int> sortOrder,
      Value<int> rowid,
    });

final class $$HabitsTableReferences
    extends BaseReferences<_$AppDatabase, $HabitsTable, HabitRow> {
  $$HabitsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CheckInsTable, List<CheckInRow>>
  _checkInsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.checkIns,
    aliasName: 'habits__id__check_ins__habit_id',
  );

  $$CheckInsTableProcessedTableManager get checkInsRefs {
    final manager = $$CheckInsTableTableManager(
      $_db,
      $_db.checkIns,
    ).filter((f) => f.habitId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_checkInsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$HabitsTableFilterComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frequencyType => $composableBuilder(
    column: $table.frequencyType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frequencyConfig => $composableBuilder(
    column: $table.frequencyConfig,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderTime => $composableBuilder(
    column: $table.reminderTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get longestStreak => $composableBuilder(
    column: $table.longestStreak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get streakFreezes => $composableBuilder(
    column: $table.streakFreezes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frozenDates => $composableBuilder(
    column: $table.frozenDates,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> checkInsRefs(
    Expression<bool> Function($$CheckInsTableFilterComposer f) f,
  ) {
    final $$CheckInsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.checkIns,
      getReferencedColumn: (t) => t.habitId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CheckInsTableFilterComposer(
            $db: $db,
            $table: $db.checkIns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$HabitsTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frequencyType => $composableBuilder(
    column: $table.frequencyType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frequencyConfig => $composableBuilder(
    column: $table.frequencyConfig,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderTime => $composableBuilder(
    column: $table.reminderTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get longestStreak => $composableBuilder(
    column: $table.longestStreak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get streakFreezes => $composableBuilder(
    column: $table.streakFreezes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frozenDates => $composableBuilder(
    column: $table.frozenDates,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HabitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<String> get frequencyType => $composableBuilder(
    column: $table.frequencyType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get frequencyConfig => $composableBuilder(
    column: $table.frequencyConfig,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reminderTime => $composableBuilder(
    column: $table.reminderTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentStreak => $composableBuilder(
    column: $table.currentStreak,
    builder: (column) => column,
  );

  GeneratedColumn<int> get longestStreak => $composableBuilder(
    column: $table.longestStreak,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get streakFreezes => $composableBuilder(
    column: $table.streakFreezes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get frozenDates => $composableBuilder(
    column: $table.frozenDates,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  Expression<T> checkInsRefs<T extends Object>(
    Expression<T> Function($$CheckInsTableAnnotationComposer a) f,
  ) {
    final $$CheckInsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.checkIns,
      getReferencedColumn: (t) => t.habitId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CheckInsTableAnnotationComposer(
            $db: $db,
            $table: $db.checkIns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$HabitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HabitsTable,
          HabitRow,
          $$HabitsTableFilterComposer,
          $$HabitsTableOrderingComposer,
          $$HabitsTableAnnotationComposer,
          $$HabitsTableCreateCompanionBuilder,
          $$HabitsTableUpdateCompanionBuilder,
          (HabitRow, $$HabitsTableReferences),
          HabitRow,
          PrefetchHooks Function({bool checkInsRefs})
        > {
  $$HabitsTableTableManager(_$AppDatabase db, $HabitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HabitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> emoji = const Value.absent(),
                Value<String> colorHex = const Value.absent(),
                Value<String> frequencyType = const Value.absent(),
                Value<String> frequencyConfig = const Value.absent(),
                Value<String?> reminderTime = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> currentStreak = const Value.absent(),
                Value<int> longestStreak = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> streakFreezes = const Value.absent(),
                Value<String?> frozenDates = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitsCompanion(
                id: id,
                name: name,
                emoji: emoji,
                colorHex: colorHex,
                frequencyType: frequencyType,
                frequencyConfig: frequencyConfig,
                reminderTime: reminderTime,
                description: description,
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                createdAt: createdAt,
                archivedAt: archivedAt,
                updatedAt: updatedAt,
                streakFreezes: streakFreezes,
                frozenDates: frozenDates,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String emoji,
                required String colorHex,
                required String frequencyType,
                required String frequencyConfig,
                Value<String?> reminderTime = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> currentStreak = const Value.absent(),
                Value<int> longestStreak = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> archivedAt = const Value.absent(),
                required DateTime updatedAt,
                Value<int> streakFreezes = const Value.absent(),
                Value<String?> frozenDates = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitsCompanion.insert(
                id: id,
                name: name,
                emoji: emoji,
                colorHex: colorHex,
                frequencyType: frequencyType,
                frequencyConfig: frequencyConfig,
                reminderTime: reminderTime,
                description: description,
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                createdAt: createdAt,
                archivedAt: archivedAt,
                updatedAt: updatedAt,
                streakFreezes: streakFreezes,
                frozenDates: frozenDates,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$HabitsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({checkInsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (checkInsRefs) db.checkIns],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (checkInsRefs)
                    await $_getPrefetchedData<
                      HabitRow,
                      $HabitsTable,
                      CheckInRow
                    >(
                      currentTable: table,
                      referencedTable: $$HabitsTableReferences
                          ._checkInsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$HabitsTableReferences(db, table, p0).checkInsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.habitId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$HabitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HabitsTable,
      HabitRow,
      $$HabitsTableFilterComposer,
      $$HabitsTableOrderingComposer,
      $$HabitsTableAnnotationComposer,
      $$HabitsTableCreateCompanionBuilder,
      $$HabitsTableUpdateCompanionBuilder,
      (HabitRow, $$HabitsTableReferences),
      HabitRow,
      PrefetchHooks Function({bool checkInsRefs})
    >;
typedef $$CheckInsTableCreateCompanionBuilder =
    CheckInsCompanion Function({
      required String id,
      required String habitId,
      required String date,
      Value<bool> completed,
      Value<String?> note,
      required DateTime loggedAt,
      Value<int> rowid,
    });
typedef $$CheckInsTableUpdateCompanionBuilder =
    CheckInsCompanion Function({
      Value<String> id,
      Value<String> habitId,
      Value<String> date,
      Value<bool> completed,
      Value<String?> note,
      Value<DateTime> loggedAt,
      Value<int> rowid,
    });

final class $$CheckInsTableReferences
    extends BaseReferences<_$AppDatabase, $CheckInsTable, CheckInRow> {
  $$CheckInsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $HabitsTable _habitIdTable(_$AppDatabase db) =>
      db.habits.createAlias('check_ins__habit_id__habits__id');

  $$HabitsTableProcessedTableManager get habitId {
    final $_column = $_itemColumn<String>('habit_id')!;

    final manager = $$HabitsTableTableManager(
      $_db,
      $_db.habits,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_habitIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CheckInsTableFilterComposer
    extends Composer<_$AppDatabase, $CheckInsTable> {
  $$CheckInsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get loggedAt => $composableBuilder(
    column: $table.loggedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$HabitsTableFilterComposer get habitId {
    final $$HabitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.habitId,
      referencedTable: $db.habits,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HabitsTableFilterComposer(
            $db: $db,
            $table: $db.habits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CheckInsTableOrderingComposer
    extends Composer<_$AppDatabase, $CheckInsTable> {
  $$CheckInsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get loggedAt => $composableBuilder(
    column: $table.loggedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$HabitsTableOrderingComposer get habitId {
    final $$HabitsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.habitId,
      referencedTable: $db.habits,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HabitsTableOrderingComposer(
            $db: $db,
            $table: $db.habits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CheckInsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CheckInsTable> {
  $$CheckInsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get loggedAt =>
      $composableBuilder(column: $table.loggedAt, builder: (column) => column);

  $$HabitsTableAnnotationComposer get habitId {
    final $$HabitsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.habitId,
      referencedTable: $db.habits,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HabitsTableAnnotationComposer(
            $db: $db,
            $table: $db.habits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CheckInsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CheckInsTable,
          CheckInRow,
          $$CheckInsTableFilterComposer,
          $$CheckInsTableOrderingComposer,
          $$CheckInsTableAnnotationComposer,
          $$CheckInsTableCreateCompanionBuilder,
          $$CheckInsTableUpdateCompanionBuilder,
          (CheckInRow, $$CheckInsTableReferences),
          CheckInRow,
          PrefetchHooks Function({bool habitId})
        > {
  $$CheckInsTableTableManager(_$AppDatabase db, $CheckInsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CheckInsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CheckInsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CheckInsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> habitId = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> loggedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CheckInsCompanion(
                id: id,
                habitId: habitId,
                date: date,
                completed: completed,
                note: note,
                loggedAt: loggedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String habitId,
                required String date,
                Value<bool> completed = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required DateTime loggedAt,
                Value<int> rowid = const Value.absent(),
              }) => CheckInsCompanion.insert(
                id: id,
                habitId: habitId,
                date: date,
                completed: completed,
                note: note,
                loggedAt: loggedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CheckInsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({habitId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (habitId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.habitId,
                                referencedTable: $$CheckInsTableReferences
                                    ._habitIdTable(db),
                                referencedColumn: $$CheckInsTableReferences
                                    ._habitIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CheckInsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CheckInsTable,
      CheckInRow,
      $$CheckInsTableFilterComposer,
      $$CheckInsTableOrderingComposer,
      $$CheckInsTableAnnotationComposer,
      $$CheckInsTableCreateCompanionBuilder,
      $$CheckInsTableUpdateCompanionBuilder,
      (CheckInRow, $$CheckInsTableReferences),
      CheckInRow,
      PrefetchHooks Function({bool habitId})
    >;
typedef $$GuestMetaTableCreateCompanionBuilder =
    GuestMetaCompanion Function({
      Value<int> id,
      required DateTime guestStartedAt,
      required String firebaseAnonymousUid,
      Value<String> migrationStatus,
      Value<bool> wasMerge,
    });
typedef $$GuestMetaTableUpdateCompanionBuilder =
    GuestMetaCompanion Function({
      Value<int> id,
      Value<DateTime> guestStartedAt,
      Value<String> firebaseAnonymousUid,
      Value<String> migrationStatus,
      Value<bool> wasMerge,
    });

class $$GuestMetaTableFilterComposer
    extends Composer<_$AppDatabase, $GuestMetaTable> {
  $$GuestMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get guestStartedAt => $composableBuilder(
    column: $table.guestStartedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firebaseAnonymousUid => $composableBuilder(
    column: $table.firebaseAnonymousUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get migrationStatus => $composableBuilder(
    column: $table.migrationStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get wasMerge => $composableBuilder(
    column: $table.wasMerge,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GuestMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $GuestMetaTable> {
  $$GuestMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get guestStartedAt => $composableBuilder(
    column: $table.guestStartedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firebaseAnonymousUid => $composableBuilder(
    column: $table.firebaseAnonymousUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get migrationStatus => $composableBuilder(
    column: $table.migrationStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get wasMerge => $composableBuilder(
    column: $table.wasMerge,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GuestMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $GuestMetaTable> {
  $$GuestMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get guestStartedAt => $composableBuilder(
    column: $table.guestStartedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get firebaseAnonymousUid => $composableBuilder(
    column: $table.firebaseAnonymousUid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get migrationStatus => $composableBuilder(
    column: $table.migrationStatus,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get wasMerge =>
      $composableBuilder(column: $table.wasMerge, builder: (column) => column);
}

class $$GuestMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GuestMetaTable,
          GuestMetaRow,
          $$GuestMetaTableFilterComposer,
          $$GuestMetaTableOrderingComposer,
          $$GuestMetaTableAnnotationComposer,
          $$GuestMetaTableCreateCompanionBuilder,
          $$GuestMetaTableUpdateCompanionBuilder,
          (
            GuestMetaRow,
            BaseReferences<_$AppDatabase, $GuestMetaTable, GuestMetaRow>,
          ),
          GuestMetaRow,
          PrefetchHooks Function()
        > {
  $$GuestMetaTableTableManager(_$AppDatabase db, $GuestMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GuestMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GuestMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GuestMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> guestStartedAt = const Value.absent(),
                Value<String> firebaseAnonymousUid = const Value.absent(),
                Value<String> migrationStatus = const Value.absent(),
                Value<bool> wasMerge = const Value.absent(),
              }) => GuestMetaCompanion(
                id: id,
                guestStartedAt: guestStartedAt,
                firebaseAnonymousUid: firebaseAnonymousUid,
                migrationStatus: migrationStatus,
                wasMerge: wasMerge,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime guestStartedAt,
                required String firebaseAnonymousUid,
                Value<String> migrationStatus = const Value.absent(),
                Value<bool> wasMerge = const Value.absent(),
              }) => GuestMetaCompanion.insert(
                id: id,
                guestStartedAt: guestStartedAt,
                firebaseAnonymousUid: firebaseAnonymousUid,
                migrationStatus: migrationStatus,
                wasMerge: wasMerge,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GuestMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GuestMetaTable,
      GuestMetaRow,
      $$GuestMetaTableFilterComposer,
      $$GuestMetaTableOrderingComposer,
      $$GuestMetaTableAnnotationComposer,
      $$GuestMetaTableCreateCompanionBuilder,
      $$GuestMetaTableUpdateCompanionBuilder,
      (
        GuestMetaRow,
        BaseReferences<_$AppDatabase, $GuestMetaTable, GuestMetaRow>,
      ),
      GuestMetaRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$HabitsTableTableManager get habits =>
      $$HabitsTableTableManager(_db, _db.habits);
  $$CheckInsTableTableManager get checkIns =>
      $$CheckInsTableTableManager(_db, _db.checkIns);
  $$GuestMetaTableTableManager get guestMeta =>
      $$GuestMetaTableTableManager(_db, _db.guestMeta);
}
