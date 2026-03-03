import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/di/injection.dart';
import '../../core/routing/app_router.dart';
import '../../data/datasources/remote/remote.dart';
import 'completion_celebration.dart';
import 'reminder_button.dart';
import 'reminder_details_modal.dart';

/// A thin wrapper around [ReminderDetailsModal] that fetches reminder data
/// from the API using an [instanceId].
///
/// Used by notification tap handlers where only the instanceId is known.
/// All UI is delegated to [ReminderDetailsModal] so every popup looks identical.
class ReminderAlertOverlay extends StatefulWidget {
  final String instanceId;
  final VoidCallback onDismiss;

  const ReminderAlertOverlay({
    super.key,
    required this.instanceId,
    required this.onDismiss,
  });

  @override
  State<ReminderAlertOverlay> createState() => _ReminderAlertOverlayState();
}

class _ReminderAlertOverlayState extends State<ReminderAlertOverlay> {
  final _reminderInstanceApi = getIt<ReminderInstanceApi>();
  final _reminderApi = getIt<ReminderApi>();

  ReminderInstanceData? _instance;
  ReminderData? _reminder;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _instance = await _reminderInstanceApi.getInstance(widget.instanceId);
      if (_instance != null) {
        _reminder = await _reminderApi.getReminder(_instance!.reminderId);
      }
    } catch (e) {
      debugPrint('ReminderAlertOverlay: Error loading data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  ReminderInstanceStatus _getStatus(String? status) {
    switch (status) {
      case 'completed':
        return ReminderInstanceStatus.completed;
      case 'missed':
        return ReminderInstanceStatus.missed;
      case 'snoozed':
        return ReminderInstanceStatus.snoozed;
      default:
        return ReminderInstanceStatus.pending;
    }
  }

  Future<void> _handleMarkDone() async {
    try {
      await _reminderInstanceApi.markCompleted(widget.instanceId);
      // Sheet is already popped by ReminderDetailsModal before this runs.
      // Alarm cleanup is handled by the .then() callback on showModalBottomSheet.

      // Delay to let bottom-sheet dismiss animation finish, then show celebration.
      Future.delayed(const Duration(milliseconds: 400), () {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null) {
          CelebrationOverlay.show(ctx, message: 'Great job!');
        }
      });
    } catch (e) {
      debugPrint('ReminderAlertOverlay: Error marking complete: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    final status = _getStatus(_instance?.status);
    final isActionable = status == ReminderInstanceStatus.pending ||
        status == ReminderInstanceStatus.snoozed;

    return ReminderDetailsModal(
      title: _reminder?.title ?? _instance?.reminderTitle ?? 'Reminder',
      scheduledTime: _instance?.scheduledTime.toLocal() ?? DateTime.now(),
      status: status,
      description: _reminder?.description ?? _instance?.reminderDescription,
      voiceNoteUrl: _reminder?.voiceNoteUrl ?? _instance?.voiceNoteUrl,
      onMarkDone: isActionable ? _handleMarkDone : null,
    );
  }
}
