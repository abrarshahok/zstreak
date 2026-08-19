import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../habits/data/local/app_database.dart';

/// One export mechanism serves two spec asks: the guest safety net
/// (Section 3a, "Export my data" before the 24-hour window closes data
/// off) and the general free-for-everyone CSV export (Section 6/3b).
/// CSV was chosen over JSON since Section 6 names CSV explicitly for the
/// general case, and Section 3a accepts either.
class DataExporter {
  DataExporter(this._db);

  final AppDatabase _db;

  Future<String> buildCsv() async {
    final habits = await _db.select(_db.habits).get();
    final habitNames = {for (final h in habits) h.id: h.name};
    final checkIns = await (_db.select(
      _db.checkIns,
    )..orderBy([(c) => OrderingTerm.asc(c.date)])).get();

    final buffer = StringBuffer('habit_name,date,completed,note\n');
    for (final c in checkIns) {
      final name = _escapeCsv(habitNames[c.habitId] ?? 'unknown');
      final note = _escapeCsv(c.note ?? '');
      buffer.writeln('$name,${c.date},${c.completed},$note');
    }
    return buffer.toString();
  }

  String _escapeCsv(String value) {
    final cleaned = value.replaceAll('"', '""');
    return cleaned.contains(',') ? '"$cleaned"' : cleaned;
  }

  /// Writes the CSV to a temp file and hands it to the OS share sheet.
  Future<void> shareCsv() async {
    final csv = await buildCsv();
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'zstreak_export.csv'));
    await file.writeAsString(csv);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'My ZStreak data export'),
    );
  }
}
