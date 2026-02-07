import 'package:flutter/widgets.dart';

import '../di/injection.dart';
import '../../data/repositories/settings_repository.dart';

/// Helper class for checking animation settings
///
/// Respects both system-level reduce motion setting and app-level toggle
class AnimationSettings {
  /// Check if animations should be shown
  ///
  /// Returns false if either:
  /// - System reduce motion is enabled (MediaQuery.disableAnimations)
  /// - App reduce animations setting is enabled
  static bool shouldAnimate(BuildContext context) {
    // Check system-level reduce motion setting
    final systemReduceMotion = MediaQuery.of(context).disableAnimations;
    if (systemReduceMotion) return false;

    // Check app-level reduce animations setting
    try {
      final settingsRepository = getIt<SettingsRepository>();
      return !settingsRepository.reduceAnimationsSync;
    } catch (e) {
      // If settings repository isn't available, allow animations
      return true;
    }
  }

  /// Get the stagger delay for list animations
  ///
  /// Returns Duration.zero if animations are disabled
  static Duration getStaggerDelay(BuildContext context, int index) {
    if (!shouldAnimate(context)) return Duration.zero;
    return Duration(milliseconds: 50 * index);
  }

  /// Get the base animation duration
  ///
  /// Returns Duration.zero if animations are disabled
  static Duration getAnimationDuration(BuildContext context, {Duration base = const Duration(milliseconds: 200)}) {
    if (!shouldAnimate(context)) return Duration.zero;
    return base;
  }
}
