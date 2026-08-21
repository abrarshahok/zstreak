/// Centralized brand-voice copy (spec Section 1a).
///
/// ZStreak's in-app slang dates fast, so every user-facing string that
/// carries the "confident gym friend" voice lives here — never hardcoded
/// in a widget — so it can be refreshed in one place every 6-12 months.
/// Plain functional UI copy (buttons, errors, settings) stays out of the
/// slang layer on purpose; only the brand-voice moments belong here.
class AppCopy {
  AppCopy._();

  // Auth screen
  static const String signInHeadline = "Let's lock in.";
  static const String continueWithGoogle = 'Continue with Google';
  static const String continueAsGuest = 'Continue as guest';
  static const String signIn = 'Sign in';
  static const String createAccount = 'Create account';

  // Onboarding / benefits (Section 3, screen 1) — sell the outcome, not
  // a feature list. Refresh the slang lines every 6-12 months.
  static const String onboardingHeadline1 = 'See your consistency at a glance.';
  static const String onboardingHeadline2 =
      'Build a streak that actually sticks.';
  static const String onboardingHeadline3 =
      "No cap, this is the simplest habit tracker you'll use.";
  static const String onboardingSignUp = 'Sign up';

  // First habit creation (Section 3, screen 4)
  static const String firstHabitHeadline = 'Create your first habit.';
  static const String firstHabitCreated =
      "First one's in. Let's build this streak.";

  // Guest mode (Section 3a's 24-hour window)
  static const String guestModeLabel = "You're in guest mode.";
  static const String guestBannerLowKey =
      'Guest mode — link an account anytime to save your streak.';
  static const String guestBannerWarning =
      'Your guest streak expires soon. Link an account to keep it.';
  static const String guestExpiredTitle = "Your guest session's up.";
  static const String guestExpiredBody =
      "Link an account to keep everything you've built — takes 10 seconds.";
  static const String guestPayingReminderBanner =
      'Link your account to protect your subscription';
  static const String linkWithGoogle = 'Link with Google';
  static const String exportMyData = 'Export my data';
  static const String linkAccount = 'Link an account';

  // New/Edit Habit (Section 3b / 5a)
  static const String frequencyChangedNotice =
      "Changing how often you track this resets your current streak, "
      "but your history's still here.";
  static const String deleteHabitConfirmTitle = 'Delete this habit?';
  static const String deleteHabitConfirmBody =
      "This permanently removes it and all its check-in history. This can't be undone.";

  // Paywall (Section 6) — headline carries the voice; pricing/terms below
  // it stay plain per store compliance norms for subscription disclosures.
  static const String paywallHeadline = 'Unlock the full grind.';
  static const String paywallRestorePurchases = 'Restore Purchases';
  static const String paywallGuestWarning =
      'Guest purchases are tied to this device only until you link an '
      "account — link first (or right after) so you don't risk losing it.";
  static const String paywallPostPurchaseLinkPrompt =
      "That's a dub. Link an account now to protect your subscription?";

  // Generic auth errors (plain, non-technical — Section 3 screen 2)
  static const String errorNetwork =
      "Couldn't connect. Check your connection and try again.";
  static const String errorInvalidCredentials =
      "That email or password isn't right.";
  static const String errorGeneric = 'Something went wrong. Try again.';
}
