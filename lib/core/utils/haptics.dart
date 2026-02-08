import 'package:flutter/services.dart';

import 'feedback_settings.dart';

/// Settings-aware haptic helpers.
class Haptics {
  static bool get _enabled => FeedbackSettings.hapticFeedbackEnabled;

  static void lightImpact() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
  }

  static void mediumImpact() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
  }

  static void heavyImpact() {
    if (!_enabled) return;
    HapticFeedback.heavyImpact();
  }

  static void selectionClick() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
  }

  static void vibrate() {
    if (!_enabled) return;
    HapticFeedback.vibrate();
  }
}
