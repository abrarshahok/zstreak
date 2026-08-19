import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../habits/application/habit_providers.dart';
import '../data/guest_meta_repository.dart';

/// Shipped duration is the real 24 hours (spec Section 3a). To manually
/// test the escalation/expiry flow during development, temporarily lower
/// this constant — swap it back before release.
const Duration guestWindowDuration = Duration(hours: 24);
const Duration guestWarningThreshold = Duration(hours: 4);

enum GuestWindowStage { active, warning, expired }

final guestMetaRepositoryProvider = Provider<GuestMetaRepository>(
  (ref) => GuestMetaRepository(ref.watch(appDatabaseProvider)),
);

final guestMetaProvider = StreamProvider((ref) {
  return ref.watch(guestMetaRepositoryProvider).watchMeta();
});

/// Re-evaluates the clock periodically so the banner escalates and the
/// interstitial appears without requiring an app relaunch.
final _guestClockTickProvider = StreamProvider<void>((ref) {
  return Stream.periodic(const Duration(seconds: 30), (_) {});
});

final guestTimeRemainingProvider = Provider<Duration>((ref) {
  ref.watch(_guestClockTickProvider);
  final meta = ref.watch(guestMetaProvider).valueOrNull;
  if (meta == null) return guestWindowDuration;
  final remaining = guestWindowDuration - DateTime.now().difference(meta.guestStartedAt);
  return remaining.isNegative ? Duration.zero : remaining;
});

final guestWindowStageProvider = Provider<GuestWindowStage>((ref) {
  final remaining = ref.watch(guestTimeRemainingProvider);
  if (remaining == Duration.zero) return GuestWindowStage.expired;
  if (remaining <= guestWarningThreshold) return GuestWindowStage.warning;
  return GuestWindowStage.active;
});
