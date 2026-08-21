/// The three account states a signed-in (non-anonymous) user can be in.
///
/// - [active] — normal use; the default for every account.
/// - [inactive] — the user deactivated their own account (replacing what
///   used to be an immediate, permanent "Delete account"). Data is kept,
///   nothing is deleted, but Firestore's own security rules deny reads
///   and writes to it until the account is reactivated.
/// - [restrict] — reserved for a future admin/moderation action, not
///   triggered anywhere in the app today. Deliberately has no self-service
///   reactivate path: only [inactive] does, since deactivation was the
///   user's own choice and restriction wouldn't be.
enum AccountStatus {
  active,
  inactive,
  restrict;

  String toDbValue() => switch (this) {
    AccountStatus.active => 'active',
    AccountStatus.inactive => 'inactive',
    AccountStatus.restrict => 'restrict',
  };

  /// Unknown or missing values default to [active] — a status field that
  /// doesn't exist yet (an account created before this feature shipped)
  /// must never read as locked-out by omission.
  static AccountStatus fromDbValue(String? value) => switch (value) {
    'inactive' => AccountStatus.inactive,
    'restrict' => AccountStatus.restrict,
    _ => AccountStatus.active,
  };
}

/// The full status record — includes the bookkeeping fields shown to the
/// user (when they deactivated, how long reactivation is guaranteed to
/// still work) alongside the status itself.
class AccountStatusRecord {
  const AccountStatusRecord({
    required this.status,
    this.deactivatedAt,
    this.reactivationDeadline,
  });

  final AccountStatus status;
  final DateTime? deactivatedAt;

  /// Informational only — nothing in the app automatically deletes or
  /// further restricts data once this passes. It's a promise about how
  /// long reactivation is guaranteed to work, not a countdown to deletion.
  final DateTime? reactivationDeadline;

  bool get isActive => status == AccountStatus.active;

  /// Days left in the 30-day reactivation window, floored at 0. Null if
  /// there's no deadline (e.g. the account was never deactivated).
  int? get daysUntilDeadline {
    if (reactivationDeadline == null) return null;
    final remaining = reactivationDeadline!.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  /// True once the 30-day reactivation window has passed for a
  /// deactivated account — computed from the stored deadline rather than
  /// a separate scheduled job flipping the status field, so it's correct
  /// the instant the window closes rather than whenever a cron next runs.
  /// From this point self-service reactivation is refused both here (the
  /// login gate stops offering it) and by Firestore's own security rules
  /// (a write attempt to flip status back to active is rejected outright,
  /// not just hidden by the UI).
  bool get isPastReactivationWindow {
    if (status != AccountStatus.inactive) return false;
    final deadline = reactivationDeadline;
    if (deadline == null) return false;
    return DateTime.now().isAfter(deadline);
  }
}
