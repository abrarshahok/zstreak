# ZStreak

A minimalist habit tracker built around a GitHub-contribution-style streak
grid — check in daily, watch the grid fill in, and keep the streak alive.

## Features

- **Habit tracking** — create habits with an emoji, color, and frequency;
  check them off daily and watch a per-habit streak grid build up over time.
- **Streaks & leveling** — current/longest streak tracking per habit, plus
  an account-wide level computed from lifetime check-ins and streaks.
- **Mood logging** — a lightweight daily mood + note check-in, correlated
  against habit consistency in Analytics.
- **Weekly Review** — a Sunday-evening/Monday recap card: check-ins, your
  best habit, and what needs work, with a shortcut into full analytics.
- **Analytics** — consistency trends, mood/habit correlation, and
  level/XP breakdowns beyond what fits on the Home screen.
- **Categories & views** — organize habits into categories, filter by
  category, and switch between list and grid layouts, with an "All" vs
  "Today" focus toggle.
- **Home screen widget** — check off a pinned habit without opening the app.
- **Data export** — export habits, check-ins, and mood logs as CSV or a
  formatted PDF report.
- **Guest mode** — use the app fully offline with on-device storage before
  ever creating an account; link a Google account later without losing data.
- **Pro subscription** — a paywalled tier (via RevenueCat) unlocks habits
  beyond the free-tier limit and other premium features.
- **Notifications** — local reminders for habits.
- **Guided first-run tour** — a spotlight walkthrough of Home for new users.
- **Account controls** — deactivate an account (data kept, reactivate any
  time within 30 days) from Settings; see [privacy policy](public/privacy.html)
  for how to request permanent deletion.

## Tech stack

- **Flutter** + **Riverpod** for state management
- **Firebase** — Auth (incl. Google Sign-In), Firestore, Crashlytics,
  Analytics, and a small Cloud Functions project
- **Drift** (SQLite) for local/offline storage in guest mode
- **RevenueCat** (`purchases_flutter`) for subscriptions
- **home_widget** for the Android/iOS home screen widget

## Project structure

```
lib/
  core/            Shared config, theme, copy, prefs, outage handling, widgets
  features/        One folder per feature (habits, analytics, auth,
                    account_linking, data_export, guest, home_tour,
                    monetization, notifications, onboarding, reviews,
                    settings, widgets)
  app.dart         App root / routing
  main.dart        Entry point, Firebase + splash init
functions/         Firebase Cloud Functions (TypeScript)
public/            Marketing landing page + hosted privacy policy/terms
test/              Unit/widget tests, mirroring lib/features structure
```

## Getting started

Prerequisites: Flutter SDK (see `environment.sdk` in `pubspec.yaml`), and a
Firebase project configured for this app (`google-services.json` /
`GoogleService-Info.plist`, not committed to this repo).

```bash
flutter pub get
flutter run
```

Run the test suite:

```bash
flutter test
```

Build a release Android App Bundle:

```bash
flutter build appbundle --release
```

### Cloud Functions

```bash
cd functions
npm install
npm run build
```

## Documentation

For general Flutter development help, see the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
