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
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Schema v2: streak freeze columns — added for a feature that was
        // never built out; dropped again in the v4 migration below.
        await customStatement(
          'ALTER TABLE habits ADD COLUMN streak_freezes INTEGER NOT NULL DEFAULT 1',
        );
        await customStatement(
          'ALTER TABLE habits ADD COLUMN frozen_dates TEXT',
        );
        // Schema v2: drag-to-reorder sort order.
        await customStatement(
          'ALTER TABLE habits ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 3) {
        // Schema v3: optional habit description.
        await customStatement('ALTER TABLE habits ADD COLUMN description TEXT');
      }
      if (from < 4) {
        // Schema v4: drop the streak-freeze columns added in v2 — no
        // repository, provider, or screen ever read or wrote either one;
        // the feature was abandoned mid-build. Requires SQLite 3.35+
        // (bundled by sqlite3_flutter_libs), which supports DROP COLUMN.
        await customStatement('ALTER TABLE habits DROP COLUMN streak_freezes');
        await customStatement('ALTER TABLE habits DROP COLUMN frozen_dates');
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
