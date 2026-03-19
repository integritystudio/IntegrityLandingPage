/// Timing constants for animations, delays, and timeouts
///
/// Centralized timing values used across services and widgets.
/// Based on Material Design duration guidelines.
class AppTimings {
  AppTimings._();

  // HTTP timeouts
  static const Duration httpTimeout = Duration(seconds: 10);
  static const Duration httpConnectTimeout = Duration(seconds: 10);
  static const Duration httpReceiveTimeout = Duration(seconds: 10);

  // User feedback durations
  static const Duration copyFeedback = Duration(seconds: 2);
  static const Duration toastDuration = Duration(seconds: 3);

  // Animation durations
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationStandard = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // Exponential backoff base delay for retries (1s, 2s, 4s...)
  static const Duration retryBaseDelay = Duration(seconds: 1);
}
