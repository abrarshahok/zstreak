import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account_linking/application/account_linking_providers.dart';
import '../../guest/application/guest_providers.dart';
import '../../habits/presentation/home_screen.dart';
import '../../monetization/application/entitlement_providers.dart';
import '../application/auth_providers.dart';

/// Runs once per signed-in session start: if a migration from Stage 6 was
/// interrupted mid-way (app closed before `migration_status` reached
/// `complete`), automatically resumes it — spec Section 5's partial-
/// failure requirement. Safe to resume blindly since both entity types
/// use deterministic Firestore doc keys, so re-writing is idempotent.
class SignedInHomeGate extends ConsumerStatefulWidget {
  const SignedInHomeGate({super.key});

  @override
  ConsumerState<SignedInHomeGate> createState() => _SignedInHomeGateState();
}

class _SignedInHomeGateState extends ConsumerState<SignedInHomeGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _resumeMigrationIfNeeded(),
    );
  }

  Future<void> _resumeMigrationIfNeeded() async {
    final meta = await ref.read(guestMetaRepositoryProvider).getMeta();
    if (meta == null || meta.migrationStatus == 'complete') return;

    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    final isPremium = await ref.read(hasActiveEntitlementProvider.future);
    await ref
        .read(migrationServiceProvider)
        .migrate(uid: uid, isMerge: meta.wasMerge, isPremium: isPremium);
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
