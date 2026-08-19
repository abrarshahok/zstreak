import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Habits, CheckIns, GuestMeta])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Feature 1: streak freeze columns (added in schema v2).
        // Raw SQL used here because generated column accessors are not
        // available until after build_runner runs.
        await customStatement(
          'ALTER TABLE habits ADD COLUMN streak_freezes INTEGER NOT NULL DEFAULT 1',
        );
        await customStatement(
          'ALTER TABLE habits ADD COLUMN frozen_dates TEXT',
        );
        // Feature 6: drag-to-reorder sort order (added in schema v2).
        await customStatement(
          'ALTER TABLE habits ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
        );
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'zstreak.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
