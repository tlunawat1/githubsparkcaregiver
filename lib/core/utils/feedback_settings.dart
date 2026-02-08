import '../di/injection.dart';
import '../../data/repositories/settings_repository.dart';

/// Cached access to feedback-related settings.
class FeedbackSettings {
  static bool _notificationSoundEnabled = true;
  static bool _hapticFeedbackEnabled = true;
  static bool _initialized = false;

  static bool get notificationSoundEnabled => _notificationSoundEnabled;
  static bool get hapticFeedbackEnabled => _hapticFeedbackEnabled;

  /// Load the current values from persistent settings.
  static Future<void> refresh() async {
    try {
      final repository = getIt<SettingsRepository>();
      _notificationSoundEnabled =
          await repository.isNotificationSoundEnabled();
      _hapticFeedbackEnabled = await repository.isHapticFeedbackEnabled();
      _initialized = true;
    } catch (_) {
      // Keep defaults if settings are unavailable.
    }
  }

  /// Ensure values are loaded before returning.
  static Future<bool> isNotificationSoundEnabled() async {
    if (!_initialized) {
      await refresh();
    }
    return _notificationSoundEnabled;
  }

  /// Ensure values are loaded before returning.
  static Future<bool> isHapticFeedbackEnabled() async {
    if (!_initialized) {
      await refresh();
    }
    return _hapticFeedbackEnabled;
  }

  static void setNotificationSoundEnabled(bool enabled) {
    _notificationSoundEnabled = enabled;
  }

  static void setHapticFeedbackEnabled(bool enabled) {
    _hapticFeedbackEnabled = enabled;
  }
}
