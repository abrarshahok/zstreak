import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'paywall_screen.dart';

/// Pushes [PaywallScreen] — guests can browse pricing and even purchase
/// there (see [PaywallScreen]'s own guest handling), so this no longer
/// gates navigation itself behind a sign-up prompt the way it used to.
Future<void> navigateToPaywall(BuildContext context, WidgetRef ref) async {
  await Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
}
