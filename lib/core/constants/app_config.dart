/// Application configuration for feature flags and settings.
/// Toggle these values to enable/disable features for local vs cloud deployment.
class AppConfig {
  AppConfig._();

  /// Whether to use remote backend (Azure) or local-only storage
  static const bool useRemoteBackend = false;

  /// Base URL for the Azure API (when useRemoteBackend is true)
  static const String apiBaseUrl = 'https://your-azure-app.azurewebsites.net';

  /// Whether to enable push notifications (requires FCM/APNs setup)
  static const bool enablePushNotifications = false;

  /// Whether to enable voice note cloud backup
  static const bool enableVoiceNoteCloudBackup = false;

  /// Maximum voice note duration in seconds
  static const int maxVoiceNoteDurationSeconds = 60;

  /// SOS long-press duration in milliseconds
  static const int sosLongPressDurationMs = 3000;

  /// SOS cancellation window in seconds
  static const int sosCancellationWindowSeconds = 10;

  /// Reminder escalation intervals
  static const int gentleReminderIntervalMinutes = 5;
  static const int repeatReminderIntervalMinutes = 10;
  static const int fullScreenReminderIntervalMinutes = 15;

  /// App name for display
  static const String appName = 'Parental Care';

  /// App version
  static const String appVersion = '1.0.0';
}
