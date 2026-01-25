import 'package:drift/drift.dart';
import '../datasources/local/database.dart';

/// Repository for app settings storage
class SettingsRepository {
  final AppDatabase _db;

  // Setting keys
  static const String keyCurrentUserId = 'current_user_id';
  static const String keyUserRole = 'user_role';
  static const String keySelectedDependentId = 'selected_dependent_id';
  static const String keyOnboardingComplete = 'onboarding_complete';
  static const String keyThemeMode = 'theme_mode';
  static const String keyHighContrast = 'high_contrast';
  static const String keyFontScale = 'font_scale';
  static const String keyNotificationSoundEnabled = 'notification_sound_enabled';
  static const String keyHapticFeedbackEnabled = 'haptic_feedback_enabled';

  SettingsRepository(this._db);

  /// Get a setting value
  Future<String?> getSetting(String key) async {
    final setting = await (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return setting?.value;
  }

  /// Set a setting value
  Future<void> setSetting(String key, String value) {
    return _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: key,
            value: value,
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// Delete a setting
  Future<int> deleteSetting(String key) {
    return (_db.delete(_db.appSettings)..where((s) => s.key.equals(key))).go();
  }

  /// Get all settings
  Future<Map<String, String>> getAllSettings() async {
    final settings = await _db.select(_db.appSettings).get();
    return {for (final s in settings) s.key: s.value};
  }

  // ==================== Convenience Methods ====================

  /// Get current user ID
  Future<String?> getCurrentUserId() => getSetting(keyCurrentUserId);

  /// Set current user ID
  Future<void> setCurrentUserId(String userId) =>
      setSetting(keyCurrentUserId, userId);

  /// Get user role
  Future<String?> getUserRole() => getSetting(keyUserRole);

  /// Set user role
  Future<void> setUserRole(String role) => setSetting(keyUserRole, role);

  /// Get selected dependent ID
  Future<String?> getSelectedDependentId() =>
      getSetting(keySelectedDependentId);

  /// Set selected dependent ID
  Future<void> setSelectedDependentId(String dependentId) =>
      setSetting(keySelectedDependentId, dependentId);

  /// Check if onboarding is complete
  Future<bool> isOnboardingComplete() async {
    final value = await getSetting(keyOnboardingComplete);
    return value == 'true';
  }

  /// Set onboarding complete
  Future<void> setOnboardingComplete(bool complete) =>
      setSetting(keyOnboardingComplete, complete.toString());

  /// Get theme mode ('system', 'light', 'dark')
  Future<String> getThemeMode() async {
    return await getSetting(keyThemeMode) ?? 'system';
  }

  /// Set theme mode
  Future<void> setThemeMode(String mode) => setSetting(keyThemeMode, mode);

  /// Check if high contrast is enabled
  Future<bool> isHighContrastEnabled() async {
    final value = await getSetting(keyHighContrast);
    return value == 'true';
  }

  /// Set high contrast
  Future<void> setHighContrast(bool enabled) =>
      setSetting(keyHighContrast, enabled.toString());

  /// Get font scale (1.0 = normal)
  Future<double> getFontScale() async {
    final value = await getSetting(keyFontScale);
    return double.tryParse(value ?? '1.0') ?? 1.0;
  }

  /// Set font scale
  Future<void> setFontScale(double scale) =>
      setSetting(keyFontScale, scale.toString());

  /// Check if notification sound is enabled
  Future<bool> isNotificationSoundEnabled() async {
    final value = await getSetting(keyNotificationSoundEnabled);
    return value != 'false'; // Default to true
  }

  /// Set notification sound enabled
  Future<void> setNotificationSoundEnabled(bool enabled) =>
      setSetting(keyNotificationSoundEnabled, enabled.toString());

  /// Check if haptic feedback is enabled
  Future<bool> isHapticFeedbackEnabled() async {
    final value = await getSetting(keyHapticFeedbackEnabled);
    return value != 'false'; // Default to true
  }

  /// Set haptic feedback enabled
  Future<void> setHapticFeedbackEnabled(bool enabled) =>
      setSetting(keyHapticFeedbackEnabled, enabled.toString());

  /// Clear all settings (for logout/reset)
  Future<void> clearAllSettings() {
    return _db.delete(_db.appSettings).go();
  }
}
