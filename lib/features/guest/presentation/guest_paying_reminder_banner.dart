import 'package:flutter/material.dart';

import '../../../core/copy/app_copy.dart';
import '../../../core/theme/app_theme.dart';
import '../../account_linking/presentation/link_account_screen.dart';

/// Section 6's paying-guest exception: a guest whose 24-hour window has
/// expired but who already has an active entitlement must never be
/// blocked — this persistent (not dismissible) banner carries the
/// urgency instead of the full-screen interstitial.
class GuestPayingReminderBanner extends StatelessWidget {
  const GuestPayingReminderBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(AppCopy.guestPayingReminderBanner, style: TextStyle(fontSize: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LinkAccountScreen()),
            ),
            child: const Text('Link'),
          ),
        ],
      ),
    );
  }
}
