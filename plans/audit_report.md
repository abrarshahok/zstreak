# ZStreak Application Audit Report

## 1. Existing Architecture

- **State Management:** The application relies on `flutter_riverpod` (v2.x) using `StreamProvider` and `Provider` for reactive data flow and dependency injection.
- **Data Layer (Repositories):** A `HabitRepository` interface abstracts the storage mechanism. `habitRepositoryProvider` swaps between `FirestoreHabitRepository` for signed-in users and `DriftHabitRepository` for anonymous/guest users.
- **Caching & Offline Behavior:** Firestore offline persistence is explicitly enabled in `main.dart` (`persistenceEnabled: true`). This provides a seamless offline experience for basic read/write operations because Firestore automatically caches data and queues offline writes.
- **UI Error Handling:** Async states in the UI are handled using Riverpod's `.when(data:, loading:, error:)` mapping. However, this is localized per widget/screen and lacks a centralized mechanism to intercept critical backend outages (e.g., quota exceeded).

## 2. Problems Found

### [CRITICAL] Unbounded Firestore Read Operations (`_recalculateStreak`)

- **Description:** In `FirestoreHabitRepository.setCheckIn()` and `useFreeze()`, the app calls `_recalculateStreak()`. This method retrieves _all_ completed check-in documents for a habit to recalculate the streak (`await _habits.doc(habitId).collection('check_ins').where('completed', isEqualTo: true).get();`).
- **Cost Risk (HIGH):** This is an O(N) operation per toggle. A user checking in daily for a year requires 365 Firestore reads just to record one new check-in. If a user quickly toggles a habit on and off, it triggers massive read spikes. This will exponentially increase Firebase billing as the user base and their history grow.
- **Recommended Fix:** Migrate streak calculation to a cloud function, or securely increment/decrement the existing streak fields using `FieldValue.increment()`, or fetch only the most recent contiguous check-ins (e.g., `limit(30)`) combined with a fallback rather than downloading the entire history client-side.
- **Change Impact:** MODERATE RISK (Requires careful modification of streak logic to avoid data inconsistency, but strictly limits billing costs).

### [HIGH] Lack of Centralized Outage Detection & Circuit Breakers

- **Description:** When Firestore reaches its quota or billing fails, it throws a `FirebaseException` (e.g., `permission-denied` or `resource-exhausted`). Currently, these exceptions propagate to localized Riverpod `.error()` states. If a widget re-mounts or auto-refreshes, it can cause retry loops.
- **Cost Risk (MEDIUM):** Although failed requests are often cheaper or blocked, rapid continuous retries drain battery and can hit secondary limits.
- **Recommended Fix:** Implement a centralized `AppStatusProvider` or interceptor. If `FirebaseException` indicates a quota or unavailability issue, open a "circuit breaker" and transition the app to the "Service Temporarily Unavailable" mode.
- **Change Impact:** SAFE / LOW RISK.

### [HIGH] No Remote Emergency Switch (Single Point of Failure)

- **Description:** The application has no mechanism to gracefully shut down or display a maintenance screen globally if the primary backend (Firebase) experiences an outage.
- **Cost Risk (LOW):** Does not generate direct costs, but severely damages user experience and App Store reviews during an incident.
- **Recommended Fix:** Implement a lightweight, external JSON configuration hosted independently of Firebase (e.g., GitHub Pages, AWS S3, or Cloudflare Pages CDN). The app fetches this config on startup. If `maintenanceMode: true`, it overrides the navigation and shows the maintenance screen.
- **Change Impact:** SAFE / LOW RISK.

## 3. Emergency Outage Protection Strategy

### Outage Detection Method

The application will detect outages through two mechanisms:

1.  **Passive Detection (Circuit Breaker):** A Riverpod provider will listen for repetitive `FirebaseException`s (specifically billing/quota/unavailable codes). If errors exceed a threshold within a time window, the circuit breaker opens, blocking further network requests and displaying the Outage Screen.
2.  **Active Configuration Check (External JSON):** On app startup and foregrounding, the app will make a lightweight HTTP GET request to an independent URL (e.g., `https://example.com/status.json`). This bypasses Firebase entirely.

### Maintenance Switch

The external JSON file will look like:

```json
{
  "maintenanceMode": true,
  "title": "We'll Be Back Soon",
  "message": "We're performing scheduled upgrades to improve your experience.",
  "retryEnabled": true
}
```

### Cost During Outage

By utilizing the Circuit Breaker pattern, if Firestore fails continuously, the app will instantly stop attempting to fetch or write data for a designated cooldown period (e.g., 5 minutes), reverting to cached data where possible or showing the maintenance screen, effectively protecting against infinite loop billing.

### Offline vs Outage

- **Offline:** Checked using `connectivity_plus` (or similar). If there's no connection, the app relies purely on Firestore's local cache. No error screens are shown unless the cache is completely empty.
- **Outage:** Triggered only when the internet is active, but the backend explicitly rejects requests (Quota/Billing) OR the external JSON file flags maintenance.

### Recovery

When the "Retry" button is pressed on the maintenance screen, the app will:

1. Re-fetch the lightweight JSON configuration.
2. If healthy, reset the Circuit Breaker.
3. Invalidate Riverpod's core data providers to trigger a fresh data load.

### Emergency Instructions (For Admin)

- **How to manually put the app into maintenance mode?** Update the hosted `status.json` file to `"maintenanceMode": true`.
- **How do I restore the app?** Change the JSON value to `false`.
- **How quickly will users receive the change?** On their next app launch, foreground event, or manual "Retry" tap.
- **What happens if Firebase itself is unavailable?** The external JSON check will still succeed, gracefully putting the app into maintenance mode.
- **What happens if the status system is unavailable?** The HTTP request times out gracefully, the app assumes `maintenanceMode: false`, and falls back to normal operations (using cache or relying on the circuit breaker if Firebase is also down).
