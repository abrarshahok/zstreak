/// Describes the current maintenance state injected into [AppHealthNotifier].
///
/// Instances are created programmatically (from Firebase error classification)
/// rather than fetched from an external API.
class AppStatus {
  const AppStatus({
    required this.maintenanceMode,
    this.title = "We'll Be Back Soon",
    this.message =
        "We're currently experiencing a temporary service interruption.\n"
        'Our team is working to restore everything as quickly as possible.\n\n'
        'Please try again in a little while.',
    this.retryEnabled = true,
    this.estimatedReturnTime,
  });

  /// Whether the app should show the maintenance/service-unavailable screen.
  final bool maintenanceMode;

  /// Title shown on the service-unavailable screen.
  final String title;

  /// Body message shown on the service-unavailable screen.
  final String message;

  /// Whether the retry button is visible.
  final bool retryEnabled;

  /// Optional human-readable estimated return time, e.g. "2:00 PM UTC".
  final String? estimatedReturnTime;

  /// The healthy default — app operates normally.
  static const AppStatus healthy = AppStatus(maintenanceMode: false);

  /// Shown when the circuit breaker opens due to critical Firebase failures
  /// while the device has internet connectivity.
  static const AppStatus backendDown = AppStatus(
    maintenanceMode: true,
    title: 'Service Temporarily Unavailable',
    message:
        "We're having trouble connecting to our servers right now.\n"
        'Your data is safe and will sync when the connection is restored.\n\n'
        'Please try again in a few minutes.',
    retryEnabled: true,
  );

  @override
  String toString() =>
      'AppStatus(maintenanceMode: $maintenanceMode, title: $title)';
}

/// Classifies the current application health state.
enum AppHealthState {
  /// App is healthy and operating normally.
  healthy,

  /// The circuit breaker has opened due to repeated critical backend failures
  /// while the device has internet connectivity.
  backendUnavailable,
}
