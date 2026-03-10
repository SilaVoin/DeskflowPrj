/// Application-wide constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'Deskflow';
  static const String appVersion = '1.0.0';

  /// Minimum search query length before triggering search.
  static const int minSearchLength = 2;

  /// Debounce duration for search input (milliseconds).
  static const int searchDebounceDuration = 300;

  /// Chat typing indicator timeout (seconds).
  static const int typingIndicatorTimeout = 3;

  /// Splash screen timeout before showing retry (seconds).
  static const int splashTimeout = 3;

  /// Resend email verification cooldown (seconds).
  static const int emailResendCooldown = 60;

  /// Default page size for paginated lists.
  static const int defaultPageSize = 20;
}
