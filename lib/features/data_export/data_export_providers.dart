import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../habits/application/habit_providers.dart';
import 'data_exporter.dart';

final dataExporterProvider = Provider<DataExporter>(
  (ref) => DataExporter(ref.watch(habitRepositoryProvider)),
);
