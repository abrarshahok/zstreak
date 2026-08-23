import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../habits/domain/habit_repository.dart';

/// One export mechanism serves two spec asks: the guest safety net
/// (Section 3a, "Export my data" before the 24-hour window closes data
/// off) and the general free-for-everyone CSV export (Section 6/3b).
/// CSV was chosen over JSON since Section 6 names CSV explicitly for the
/// general case, and Section 3a accepts either.
class DataExporter {
  DataExporter(this._repo);

  // Not AppDatabase (Drift) directly — that's only ever correct for
  // guests. A signed-in user's real habits live in Firestore
  // (habitRepositoryProvider routes on auth state, same as every other
  // screen), so reading Drift straight for them silently produced an
  // empty/stale export that still looked successful.
  final HabitRepository _repo;

  Future<String> buildCsv() async {
    final active = await _repo.watchActiveHabits().first;
    final archived = await _repo.watchArchivedHabits().first;
    final habits = [...active, ...archived];
    final habitNames = {for (final h in habits) h.id: h.name};

    final buffer = StringBuffer('habit_name,date,status,value,note\n');
    for (final habit in habits) {
      final checkIns = await _repo.watchHabitCheckIns(habit.id).first;
      final sorted = checkIns.toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      for (final c in sorted) {
        final name = _escapeCsv(habitNames[c.habitId] ?? 'unknown');
        final note = _escapeCsv(c.note ?? '');
        buffer.writeln(
          '$name,${c.date},${c.status.toDbValue()},${c.value ?? ''},$note',
        );
      }
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
