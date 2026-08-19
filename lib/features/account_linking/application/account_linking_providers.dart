import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firestore_providers.dart';
import '../../guest/application/guest_providers.dart';
import '../../habits/application/habit_providers.dart';
import '../data/migration_service.dart';

final migrationServiceProvider = Provider<MigrationService>((ref) {
  return MigrationService(
    ref.watch(appDatabaseProvider),
    ref.watch(firestoreProvider),
    ref.watch(guestMetaRepositoryProvider),
  );
});
