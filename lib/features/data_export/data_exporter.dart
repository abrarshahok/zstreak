import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/config/app_config.dart';
import '../auth/data/auth_repository.dart';
import '../habits/domain/check_in.dart';
import '../habits/domain/check_in_status.dart';
import '../habits/domain/frequency.dart';
import '../habits/domain/habit.dart';
import '../habits/domain/habit_category.dart';
import '../habits/domain/habit_repository.dart';
import '../habits/domain/streak_calculator.dart';

/// One repository serves two export formats: the guest safety net (spec
/// Section 3a, "Export my data" before the 24-hour window closes data off)
/// and the general free-for-everyone export (Section 6/3b) — CSV as a
/// clearly-sectioned, spreadsheet-friendly file, PDF as a formatted report
/// with tables and a bit of visual analytics. Both are built from the same
/// [_buildReportData] so the two formats never disagree with each other.
/// The user picks between them at the call site (see
/// `export_format_sheet.dart`); this class just knows how to build each.
class DataExporter {
  DataExporter(this._repo, this._auth);

  // Not AppDatabase (Drift) directly — that's only ever correct for
  // guests. A signed-in user's real habits live in Firestore
  // (habitRepositoryProvider routes on auth state, same as every other
  // screen), so reading Drift straight for them silently produced an
  // empty/stale export that still looked successful.
  final HabitRepository _repo;
  final AuthRepository _auth;

  /// [isPro] is resolved by the caller (the export-format sheet already
  /// checks entitlement to decide whether to lock PDF at all) rather than
  /// read from RevenueCat again here — keeps this class's dependencies to
  /// just habits/auth, and the two checks can never disagree with each
  /// other about which tier the user is on.
  Future<_ReportData> _buildReportData({required bool isPro}) async {
    final allActive = await _repo.watchActiveHabits().first;
    final allArchived = await _repo.watchArchivedHabits().first;

    // Free tier: export capacity mirrors what a free user is actually
    // allowed to have going forward — up to [AppConfig.freeTierHabitLimit]
    // active habits, no archived ones. Most-recently-created first covers
    // the one way a free user can end up over the cap: they had Pro,
    // created more, then lost it — the limit only blocks *new* creation,
    // it never retroactively removes existing habits.
    List<Habit> active = allActive;
    List<Habit> archived = allArchived;
    var omittedCount = 0;
    if (!isPro) {
      omittedCount += allArchived.length;
      archived = const [];
      if (allActive.length > AppConfig.freeTierHabitLimit) {
        final sorted = allActive.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        active = sorted.take(AppConfig.freeTierHabitLimit).toList();
        omittedCount += allActive.length - active.length;
      }
    }

    final habits = [...active, ...archived];

    final checkInsByHabit = <String, List<CheckIn>>{};
    for (final habit in habits) {
      checkInsByHabit[habit.id] = await _repo
          .watchHabitCheckIns(habit.id)
          .first;
    }

    final customCategories = await _repo.watchCategories().first;
    final categoryNames = {
      for (final c in kPredefinedCategories) c.id: c.name,
      for (final c in customCategories) c.id: c.name,
    };

    final rows = <_HabitReportRow>[];
    for (final habit in habits) {
      final detail = await _repo
          .watchStreakDetail(
            habitId: habit.id,
            frequencyType: habit.frequencyType,
            frequencyConfig: habit.frequencyConfig,
            createdAt: habit.createdAt,
          )
          .first;
      final completedCount = checkInsByHabit[habit.id]!
          .where((c) => c.status == CheckInStatus.completed)
          .length;
      rows.add(
        _HabitReportRow(
          habit: habit,
          streak: detail,
          completedCount: completedCount,
        ),
      );
    }

    final totalCheckIns = rows.fold<int>(0, (sum, r) => sum + r.completedCount);
    final longest = rows.isEmpty
        ? null
        : rows.reduce(
            (a, b) => b.streak.longestStreak > a.streak.longestStreak ? b : a,
          );
    final activeRows = rows.where((r) => r.habit.archivedAt == null).toList();
    final avgCompletion = activeRows.isEmpty
        ? 0.0
        : activeRows.fold<double>(
                0,
                (sum, r) => sum + r.streak.completionRate,
              ) /
              activeRows.length;

    const weeks = 12;
    final weeklyTotals = _weeklyCompletionTotals(checkInsByHabit, weeks: weeks);

    return _ReportData(
      generatedAt: DateTime.now(),
      habits: habits,
      checkInsByHabit: checkInsByHabit,
      categoryNames: categoryNames,
      rows: rows,
      activeCount: active.length,
      archivedCount: archived.length,
      totalCheckIns: totalCheckIns,
      longest: longest,
      avgCompletion: avgCompletion,
      weeklyTotals: weeklyTotals,
      userInfoRows: _userInfoRows(),
      omittedHabitCount: omittedCount,
    );
  }

  /// Who this export belongs to — a plain-language account summary, not
  /// raw ids: guests get a one-line "data lives on this device" note;
  /// signed-in users get whatever Firebase actually has (name/email are
  /// both optional on the [User] object, so each is only added if set).
  List<List<String>> _userInfoRows() {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      return [
        ['Account type', 'Guest (data stored on this device only)'],
      ];
    }
    final rows = <List<String>>[
      ['Account type', 'Signed in'],
    ];
    final name = user.displayName;
    if (name != null && name.trim().isNotEmpty) {
      rows.add(['Name', name]);
    }
    final email = user.email;
    if (email != null && email.trim().isNotEmpty) {
      rows.add(['Email', email]);
    }
    final created = user.metadata.creationTime;
    if (created != null) {
      rows.add(['Member since', _formatDate(created)]);
    }
    return rows;
  }

  // ─── CSV ─────────────────────────────────────────────────────────────────

  Future<String> buildCsv({required bool isPro}) async {
    final data = await _buildReportData(isPro: isPro);
    final buffer = StringBuffer();

    buffer.writeln(_csvRow(['ZStreak Data Export']));
    buffer.writeln(_csvRow(['Generated', _formatDate(data.generatedAt)]));
    if (data.isCapped) {
      buffer.writeln(_csvRow(['Note', _capNote(data)]));
    }
    buffer.writeln();

    buffer.writeln(_csvRow(['Account']));
    for (final row in data.userInfoRows) {
      buffer.writeln(_csvRow(row));
    }
    buffer.writeln();

    buffer.writeln(_csvRow(['Summary']));
    for (final row in _summaryRows(data)) {
      buffer.writeln(_csvRow(row));
    }
    buffer.writeln();

    buffer.writeln(_csvRow(['Habit Breakdown']));
    buffer.writeln(
      _csvRow([
        'habit_name',
        'category',
        'frequency',
        'status',
        'current_streak',
        'longest_streak',
        'completion_rate',
        'total_check_ins',
      ]),
    );
    for (final r in data.rows) {
      buffer.writeln(
        _csvRow([
          r.habit.name,
          r.habit.categoryId == null
              ? '-'
              : (data.categoryNames[r.habit.categoryId] ?? '-'),
          _frequencyLabel(r.habit),
          r.habit.archivedAt == null ? 'Active' : 'Archived',
          '${r.streak.currentStreak}',
          '${r.streak.longestStreak}',
          '${(r.streak.completionRate * 100).round()}%',
          '${r.completedCount}',
        ]),
      );
    }
    buffer.writeln();

    buffer.writeln(_csvRow(['Check-ins']));
    buffer.writeln(_csvRow(['habit_name', 'date', 'status', 'value', 'note']));
    for (final habit in data.habits) {
      final sorted = (data.checkInsByHabit[habit.id] ?? const []).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      for (final c in sorted) {
        buffer.writeln(
          _csvRow([
            habit.name,
            c.date,
            c.status.toDbValue(),
            c.value?.toString() ?? '',
            c.note ?? '',
          ]),
        );
      }
    }

    return buffer.toString();
  }

  String _csvRow(List<String> cells) => cells.map(_escapeCsv).join(',');

  String _escapeCsv(String value) {
    final cleaned = value.replaceAll('"', '""');
    final needsQuoting =
        cleaned.contains(',') ||
        cleaned.contains('\n') ||
        cleaned.contains('\r');
    return needsQuoting ? '"$cleaned"' : cleaned;
  }

  /// Writes the CSV to a temp file and hands it to the OS share sheet.
  Future<void> shareCsv({required bool isPro}) async {
    final csv = await buildCsv(isPro: isPro);
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(dir.path, '${_fileNameBase('ZStreak_Export')}.csv'),
    );
    await file.writeAsString(csv);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'My ZStreak data export'),
    );
  }

  List<List<String>> _summaryRows(_ReportData data) => [
    ['Total habits', '${data.habits.length}'],
    ['Active habits', '${data.activeCount}'],
    ['Archived habits', '${data.archivedCount}'],
    ['Total check-ins logged', '${data.totalCheckIns}'],
    [
      'Longest streak',
      data.longest == null
          ? '-'
          : '${data.longest!.streak.longestStreak} days (${data.longest!.habit.name})',
    ],
    [
      'Avg. completion rate (active habits)',
      '${(data.avgCompletion * 100).round()}%',
    ],
  ];

  /// Explains a free-tier truncation instead of silently shipping a
  /// shorter export than the user actually has — a capped file with no
  /// explanation just reads as data loss.
  String _capNote(_ReportData data) {
    final total = data.habits.length + data.omittedHabitCount;
    return 'Free plan - showing ${data.habits.length} of $total habits '
        '(most recent, active only). Upgrade to Pro to export everything.';
  }

  // ─── PDF report ─────────────────────────────────────────────────────────

  /// Builds a formatted analytics report: account info, a summary of
  /// totals, a 12-week activity bar chart, and a per-habit breakdown
  /// table — the same current/longest-streak and completion-rate numbers
  /// Analytics shows, via the same [HabitRepository.watchStreakDetail] it
  /// reads from, rather than a second copy of the streak math.
  Future<Uint8List> buildPdfBytes({required bool isPro}) async {
    final data = await _buildReportData(isPro: isPro);
    const weeks = 12;

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 36, 32, 32),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Page ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          ),
        ),
        build: (context) => [
          pw.Text(
            'ZStreak Data Export',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated ${_formatDate(data.generatedAt)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          if (data.isCapped) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.amber50,
                border: pw.Border.all(color: PdfColors.amber200),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Text(
                _capNote(data),
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.brown800,
                ),
              ),
            ),
          ],
          pw.SizedBox(height: 24),
          _sectionTitle('Account'),
          pw.SizedBox(height: 10),
          _keyValueTable(data.userInfoRows),
          pw.SizedBox(height: 28),
          _sectionTitle('Summary'),
          pw.SizedBox(height: 10),
          _keyValueTable(_summaryRows(data)),
          pw.SizedBox(height: 28),
          _sectionTitle('Weekly Activity - last $weeks weeks'),
          pw.SizedBox(height: 14),
          _weeklyBarChart(data.weeklyTotals),
          pw.SizedBox(height: 28),
          _sectionTitle('Habit Breakdown'),
          pw.SizedBox(height: 10),
          _habitTable(data.rows, data.categoryNames),
        ],
      ),
    );

    return doc.save();
  }

  /// Writes the PDF report to a temp file and hands it to the OS share
  /// sheet — same mechanism [shareCsv] already uses.
  Future<void> sharePdf({required bool isPro}) async {
    final bytes = await buildPdfBytes(isPro: isPro);
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(dir.path, '${_fileNameBase('ZStreak_Report')}.pdf'),
    );
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'My ZStreak data export'),
    );
  }

  pw.Widget _sectionTitle(String title) => pw.Text(
    title,
    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
  );

  pw.Widget _keyValueTable(List<List<String>> rows) {
    return pw.TableHelper.fromTextArray(
      data: rows,
      border: null,
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 4),
      cellAlignments: const {1: pw.Alignment.centerRight},
      columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(2)},
      textStyleBuilder: (index, cell, rowNum) => pw.TextStyle(
        fontSize: 11,
        fontWeight: index == 1 ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    );
  }

  pw.Widget _weeklyBarChart(List<int> totals) {
    const maxBarHeight = 90.0;
    final maxValue = totals.fold<int>(0, (m, v) => v > m ? v : m);
    final now = DateTime.now();
    final currentWeekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: List.generate(totals.length, (i) {
        final value = totals[i];
        final barHeight = maxValue == 0
            ? 0.0
            : (value / maxValue) * maxBarHeight;
        final weekStart = currentWeekStart.subtract(
          Duration(days: 7 * (totals.length - 1 - i)),
        );
        return pw.Expanded(
          child: pw.Column(
            children: [
              pw.Text(
                '$value',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Container(
                height: maxBarHeight,
                alignment: pw.Alignment.bottomCenter,
                child: pw.Container(
                  height: value == 0 ? 0 : (barHeight < 3 ? 3 : barHeight),
                  margin: const pw.EdgeInsets.symmetric(horizontal: 3),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.deepPurple400,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '${weekStart.month}/${weekStart.day}',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  pw.Widget _habitTable(
    List<_HabitReportRow> rows,
    Map<String, String> categoryNames,
  ) {
    final headers = [
      'Habit',
      'Category',
      'Frequency',
      'Status',
      'Current',
      'Longest',
      'Completion',
      'Check-ins',
    ];
    final data = rows.map((r) {
      final categoryName = r.habit.categoryId == null
          ? '-'
          : (categoryNames[r.habit.categoryId] ?? '-');
      return [
        r.habit.name,
        categoryName,
        _frequencyLabel(r.habit),
        r.habit.archivedAt == null ? 'Active' : 'Archived',
        '${r.streak.currentStreak}d',
        '${r.streak.longestStreak}d',
        '${(r.streak.completionRate * 100).round()}%',
        '${r.completedCount}',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.deepPurple400),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      cellAlignments: const {
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.centerRight,
      },
      headerAlignments: const {
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.centerRight,
      },
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
    );
  }

  String _frequencyLabel(Habit habit) {
    return switch (habit.frequencyType) {
      FrequencyType.daily => 'Every day',
      FrequencyType.weekdays => 'Weekdays',
      FrequencyType.xPerWeek =>
        '${(habit.frequencyConfig as XPerWeekConfig).timesPerWeek}x/week',
    };
  }

  /// Monday-anchored weekly buckets, oldest first, matching the week-start
  /// convention [NotificationOrchestrator]'s weekly summary already uses.
  List<int> _weeklyCompletionTotals(
    Map<String, List<CheckIn>> checkInsByHabit, {
    required int weeks,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentWeekStart = today.subtract(Duration(days: today.weekday - 1));
    final oldestWeekStart = currentWeekStart.subtract(
      Duration(days: 7 * (weeks - 1)),
    );

    final totals = List<int>.filled(weeks, 0);
    for (final checkIns in checkInsByHabit.values) {
      for (final c in checkIns) {
        if (c.status != CheckInStatus.completed) continue;
        final date = DateTime.parse(c.date);
        if (date.isBefore(oldestWeekStart)) continue;
        final weekIndex = date.difference(oldestWeekStart).inDays ~/ 7;
        if (weekIndex >= 0 && weekIndex < weeks) totals[weekIndex]++;
      }
    }
    return totals;
  }

  static const _kMonthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDate(DateTime date) =>
      '${_kMonthNames[date.month - 1]} ${date.day}, ${date.year}';

  /// Sortable, filesystem-safe date for the shared file's name — distinct
  /// from [_formatDate]'s human-readable form used inside the document
  /// itself, so two exports from the same day don't silently overwrite
  /// each other in the OS share target and multiple exports sort
  /// chronologically by filename.
  String _fileNameDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// `ZStreak_Export_Jane_Doe_2026-08-23` — the user's own name in the
  /// filename so a share sheet, downloads folder, or email attachment
  /// list reads as *whose* export it is at a glance, not just what kind.
  /// Falls back to no name for guests or a signed-in user with none set.
  String _fileNameBase(String prefix) {
    final date = _fileNameDate(DateTime.now());
    final name = _auth.currentUser?.displayName;
    if (name == null || name.trim().isEmpty) return '${prefix}_$date';
    final safeName = _sanitizeForFileName(name);
    return safeName.isEmpty ? '${prefix}_$date' : '${prefix}_${safeName}_$date';
  }

  String _sanitizeForFileName(String value) {
    final collapsed = value.trim().replaceAll(RegExp(r'\s+'), '_');
    final stripped = collapsed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
    return stripped.length > 40 ? stripped.substring(0, 40) : stripped;
  }
}

class _HabitReportRow {
  const _HabitReportRow({
    required this.habit,
    required this.streak,
    required this.completedCount,
  });

  final Habit habit;
  final StreakResult streak;
  final int completedCount;
}

/// Everything both [DataExporter.buildCsv] and [DataExporter.buildPdfBytes]
/// need, computed once so the two formats can never disagree with each
/// other about a total.
class _ReportData {
  const _ReportData({
    required this.generatedAt,
    required this.habits,
    required this.checkInsByHabit,
    required this.categoryNames,
    required this.rows,
    required this.activeCount,
    required this.archivedCount,
    required this.totalCheckIns,
    required this.longest,
    required this.avgCompletion,
    required this.weeklyTotals,
    required this.userInfoRows,
    required this.omittedHabitCount,
  });

  final DateTime generatedAt;
  final List<Habit> habits;
  final Map<String, List<CheckIn>> checkInsByHabit;
  final Map<String, String> categoryNames;
  final List<_HabitReportRow> rows;
  final int activeCount;
  final int archivedCount;
  final int totalCheckIns;
  final _HabitReportRow? longest;
  final double avgCompletion;
  final List<int> weeklyTotals;
  final List<List<String>> userInfoRows;

  /// Habits left out of this export by the free-tier cap: 0 for Pro users
  /// or a free user already within the cap.
  final int omittedHabitCount;

  bool get isCapped => omittedHabitCount > 0;
}
