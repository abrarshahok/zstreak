import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_status.dart';

// ── Circuit breaker (singleton, lives for the app lifetime) ──────────────────

/// A single shared circuit breaker instance. Kept as a plain Provider so it
/// is never recreated — its mutable state must persist across rebuilds.
final circuitBreakerProvider = Provider<CircuitBreaker>((ref) {
  return CircuitBreaker(threshold: 3, cooldown: const Duration(minutes: 5));
});

// ── App health state notifier ─────────────────────────────────────────────────

/// Holds the current [AppStatus].
///
/// Starts healthy. Transitions to [AppStatus.backendDown] only when
/// [notifyBackendFailure] is called (i.e. the circuit breaker opens after
/// repeated critical Firebase errors while the device has internet).
///
/// Recovers to [AppStatus.healthy] when [notifyBackendSuccess] is called
/// (i.e. a Firebase request succeeds after the cooldown period).
class AppHealthNotifier extends Notifier<AppStatus> {
  @override
  AppStatus build() => AppStatus.healthy;

  /// Called by [FirestoreGuard] when the circuit breaker opens.
  /// Transitions the app to the service-unavailable screen.
  void notifyBackendFailure() {
    if (state.maintenanceMode) return; // already showing outage screen
    state = AppStatus.backendDown;
  }

  /// Called by [FirestoreGuard] when a Firebase request succeeds.
  /// Resets the circuit breaker and restores the healthy state.
  void notifyBackendSuccess() {
    ref.read(circuitBreakerProvider).recordSuccess();
    if (state.maintenanceMode) {
      state = AppStatus.healthy;
    }
  }

  /// Re-checks health. Called when the user presses Retry on the
  /// service-unavailable screen. Resets the circuit breaker so the next
  /// real Firebase request can probe whether the backend has recovered.
  void reset() {
    ref.read(circuitBreakerProvider).reset();
    state = AppStatus.healthy;
  }
}

final appHealthProvider = NotifierProvider<AppHealthNotifier, AppStatus>(
  AppHealthNotifier.new,
);

// ── Derived health state ──────────────────────────────────────────────────────

/// Synchronous view of the current health state. Screens watch this to
/// decide what to render.
final appHealthStateProvider = Provider<AppHealthState>((ref) {
  final status = ref.watch(appHealthProvider);
  return status.maintenanceMode
      ? AppHealthState.backendUnavailable
      : AppHealthState.healthy;
});

// ── Circuit breaker ───────────────────────────────────────────────────────────
// Kept in this file to avoid a separate import in firestore_guard.dart.

/// Tracks consecutive critical Firebase failures and opens a circuit after
/// [threshold] failures, preventing further requests for [cooldown] duration.
class CircuitBreaker {
  CircuitBreaker({
    this.threshold = 3,
    this.cooldown = const Duration(minutes: 5),
  });

  final int threshold;
  final Duration cooldown;

  int _failureCount = 0;
  DateTime? _lastFailureTime;

  /// Whether the circuit is open (backend considered unavailable).
  bool get isOpen {
    if (_failureCount < threshold) return false;
    if (_lastFailureTime != null &&
        DateTime.now().difference(_lastFailureTime!) > cooldown) {
      return false; // half-open: allow one probe
    }
    return true;
  }

  void recordSuccess() {
    _failureCount = 0;
    _lastFailureTime = null;
  }

  /// Returns true if the circuit just opened.
  bool recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();
    return isOpen;
  }

  void reset() {
    _failureCount = 0;
    _lastFailureTime = null;
  }
}
