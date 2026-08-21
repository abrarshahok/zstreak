import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_status_providers.dart';

/// Wraps a Firestore call with circuit-breaker protection and connectivity
/// awareness.
///
/// Decision flow:
/// ```
/// Firebase operation fails
///     ↓
/// Check internet connectivity
///     ↓
/// No internet → rethrow (Firestore offline cache handles it)
///
/// Internet available
///     ↓
/// Classify Firebase error code
///     ↓
/// Critical quota/service failure → open circuit → show outage screen
/// Other error                    → rethrow (normal per-screen handling)
/// ```
///
/// Usage (inside a repository or notifier that has access to a [Ref]):
/// ```dart
/// final result = await FirestoreGuard.run(
///   ref,
///   () => _firestore.collection('habits').get(),
/// );
/// ```
class FirestoreGuard {
  FirestoreGuard._();

  /// Firebase error codes that indicate a critical backend failure.
  /// These trigger the circuit breaker and the service-unavailable screen.
  static const _criticalCodes = {
    'resource-exhausted', // quota / billing limit hit
    'unavailable', // Firestore service temporarily down
    'internal', // unexpected server error
    'deadline-exceeded', // server-side timeout
    'storage/quota-exceeded', // Storage quota (belt-and-suspenders)
    'aborted', // transaction aborted repeatedly
    'data-loss', // unrecoverable data loss
  };

  /// Executes [call] with circuit-breaker protection.
  ///
  /// On success: records success, returns the result.
  /// On critical Firebase error (with internet): may open the circuit and
  ///   trigger the outage screen.
  /// On no-internet or non-critical error: rethrows for normal handling.
  static Future<T> run<T>(Ref ref, Future<T> Function() call) async {
    final breaker = ref.read(circuitBreakerProvider);

    // If the circuit is already open, fail fast without a network call.
    if (breaker.isOpen) {
      ref.read(appHealthProvider.notifier).notifyBackendFailure();
      throw const FirestoreGuardException(
        'Circuit breaker is open — backend unavailable.',
      );
    }

    try {
      final result = await call();
      // Success — reset failure count and restore healthy state.
      ref.read(appHealthProvider.notifier).notifyBackendSuccess();
      return result;
    } on FirebaseException catch (e) {
      if (_criticalCodes.contains(e.code)) {
        // Only count as a backend failure if the device actually has internet.
        // If there's no internet, Firestore's offline cache handles it and
        // we must NOT show the outage screen.
        final hasInternet = await _hasInternetConnectivity();
        if (hasInternet) {
          final opened = breaker.recordFailure();
          if (opened) {
            ref.read(appHealthProvider.notifier).notifyBackendFailure();
          }
        }
      }
      rethrow;
    }
  }

  /// Performs a lightweight DNS lookup to determine if the device has
  /// internet connectivity. Uses dart:io — no extra package required.
  ///
  /// Returns false on any error (no internet, DNS failure, etc.).
  static Future<bool> _hasInternetConnectivity() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

/// Thrown by [FirestoreGuard.run] when the circuit breaker is open.
class FirestoreGuardException implements Exception {
  const FirestoreGuardException(this.message);
  final String message;

  @override
  String toString() => 'FirestoreGuardException: $message';
}
