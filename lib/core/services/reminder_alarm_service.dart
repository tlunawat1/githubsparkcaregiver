import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../shared/widgets/reminder_alert_overlay.dart';

/// Singleton service that manages alarm sound playback and alert overlay display.
///
/// Plays a looping custom alarm sound and shows a non-dismissible bottom sheet
/// when a reminder notification arrives (foreground) or is tapped (background).
class ReminderAlarmService {
  static final ReminderAlarmService instance = ReminderAlarmService._();
  ReminderAlarmService._();

  final AudioPlayer _player = AudioPlayer();
  bool _isAlarmActive = false;
  String? _activeInstanceId;

  GlobalKey<NavigatorState>? _navigatorKey;
  String? _pendingInstanceId;

  /// Set this to the root navigator key so we can show overlays from anywhere.
  GlobalKey<NavigatorState>? get navigatorKey => _navigatorKey;

  set navigatorKey(GlobalKey<NavigatorState>? key) {
    _navigatorKey = key;
    _schedulePendingStartAttempts();
  }

  /// Trigger the alarm for a given reminder instance.
  ///
  /// Plays the custom alarm sound in a loop and shows the alert overlay.
  /// If an alarm is already active, this is a no-op to prevent stacking.
  Future<void> triggerAlarm(String instanceId) async {
    if (_isAlarmActive) {
      debugPrint('ReminderAlarmService: Alarm already active, ignoring duplicate');
      return;
    }

    // During cold start (notification tap), the app may not have a navigator
    // context yet. Queue it and start as soon as navigatorKey is available.
    final context = _navigatorKey?.currentContext;
    if (context == null) {
      debugPrint(
          'ReminderAlarmService: No navigator context available yet; queueing alarm for $instanceId');
      _pendingInstanceId = instanceId;
      _schedulePendingStartAttempts();
      return;
    }

    _startAlarmWithOverlay(context, instanceId);
  }

  /// Stop the alarm sound and cancel the auto-stop timer.
  Future<void> stopAlarm() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('ReminderAlarmService: Error stopping player: $e');
    }

    _isAlarmActive = false;
    _activeInstanceId = null;
    _pendingInstanceId = null;
  }

  /// Whether an alarm is currently active.
  bool get isAlarmActive => _isAlarmActive;

  /// The instance ID of the currently active alarm, if any.
  String? get activeInstanceId => _activeInstanceId;

  /// Start only the continuous alarm sound (no overlay).
  ///
  /// Used by [ReminderAlertScreen] for Level >= 2 escalations so the
  /// full-screen route can manage the alarm lifecycle itself.
  Future<void> startAlarmSound(String instanceId) async {
    if (_isAlarmActive) return;
    _isAlarmActive = true;
    _activeInstanceId = instanceId;
    await _startAlarmSound();
  }

  Future<void> _startAlarmSound() async {
    try {
      // Set release mode to loop so audio repeats
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('audio/reminder_alarm.mp3'));
    } catch (e) {
      debugPrint('ReminderAlarmService: Error playing alarm sound: $e');
    }
  }

  void _startAlarmWithOverlay(BuildContext context, String instanceId) {
    _isAlarmActive = true;
    _activeInstanceId = instanceId;

    // Show the alert overlay immediately while we start audio in the background.
    // This avoids holding a BuildContext across an async gap.
    _showAlertOverlay(context, instanceId);
    // Fire-and-forget; errors are handled internally.
    _startAlarmSound();
  }

  void _tryStartPendingAlarmIfReady() {
    final instanceId = _pendingInstanceId;
    if (instanceId == null) return;
    if (_isAlarmActive) return;

    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    debugPrint('ReminderAlarmService: Starting queued alarm for $instanceId');
    _pendingInstanceId = null;
    // Fire-and-forget; UI/audio errors are already handled inside.
    _startAlarmWithOverlay(context, instanceId);
  }

  void _schedulePendingStartAttempts() {
    if (_pendingInstanceId == null) return;
    if (_isAlarmActive) return;

    // Try immediately.
    _tryStartPendingAlarmIfReady();

    // Then try after the first frame and a short delay, because `navigatorKey`
    // can be set before `currentContext` becomes available during cold start.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryStartPendingAlarmIfReady();
    });
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      _tryStartPendingAlarmIfReady();
    });
  }

  void _showAlertOverlay(BuildContext context, String instanceId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return ReminderAlertOverlay(
          instanceId: instanceId,
          onDismiss: () {
            stopAlarm();
            Navigator.of(sheetContext).pop();
          },
        );
      },
    ).then((_) {
      // Ensure alarm is stopped if sheet is somehow dismissed
      if (_isAlarmActive) {
        stopAlarm();
      }
    });
  }
}
