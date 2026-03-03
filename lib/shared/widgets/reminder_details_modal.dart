import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/haptics.dart';
import 'reminder_button.dart';

/// A bottom sheet modal showing reminder details with voice note player
/// and action buttons.
class ReminderDetailsModal extends StatefulWidget {
  const ReminderDetailsModal({
    super.key,
    required this.title,
    required this.scheduledTime,
    required this.status,
    this.description,
    this.voiceNoteUrl,
    this.onMarkDone,
    this.onSnooze,
  });

  final String title;
  final DateTime scheduledTime;
  final ReminderInstanceStatus status;
  final String? description;
  final String? voiceNoteUrl;
  final VoidCallback? onMarkDone;
  final VoidCallback? onSnooze;

  /// Show the modal as a bottom sheet
  static Future<void> show(
    BuildContext context, {
    required String title,
    required DateTime scheduledTime,
    required ReminderInstanceStatus status,
    String? description,
    String? voiceNoteUrl,
    VoidCallback? onMarkDone,
    VoidCallback? onSnooze,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReminderDetailsModal(
        title: title,
        scheduledTime: scheduledTime,
        status: status,
        description: description,
        voiceNoteUrl: voiceNoteUrl,
        onMarkDone: onMarkDone,
        onSnooze: onSnooze,
      ),
    );
  }

  @override
  State<ReminderDetailsModal> createState() => _ReminderDetailsModalState();
}

class _ReminderDetailsModalState extends State<ReminderDetailsModal> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _playVoiceNote() async {
    if (widget.voiceNoteUrl == null) return;

    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.play(UrlSource(widget.voiceNoteUrl!));
      }
    } catch (e) {
      debugPrint('Error playing voice note: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (statusColor, statusIcon, statusLabel) = switch (widget.status) {
      ReminderInstanceStatus.pending => (
          AppColors.warning,
          Icons.schedule,
          'Pending',
        ),
      ReminderInstanceStatus.completed => (
          AppColors.success,
          Icons.check_circle,
          'Completed',
        ),
      ReminderInstanceStatus.missed => (
          AppColors.error,
          Icons.error,
          'Missed',
        ),
      ReminderInstanceStatus.snoozed => (
          Colors.blue,
          Icons.snooze,
          'Snoozed',
        ),
    };

    final isActionable = widget.status == ReminderInstanceStatus.pending ||
        widget.status == ReminderInstanceStatus.snoozed;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40.w,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Status chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.circular),
                  border: Border.all(color: statusColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      statusLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Scheduled time
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    DateFormat('EEEE, MMMM d \'at\' h:mm a')
                        .format(widget.scheduledTime),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Title
              Text(
                widget.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              // Description
              if (widget.description != null &&
                  widget.description!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  widget.description!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],

              // Voice note player
              if (widget.voiceNoteUrl != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _VoiceNotePlayer(
                  isPlaying: _isPlaying,
                  onPlayPause: _playVoiceNote,
                ),
              ],

              // Action buttons
              if (isActionable) ...[
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: AppTouchTargets.elderly,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Haptics.mediumImpact();
                                  Navigator.pop(context);
                                  widget.onMarkDone?.call();
                                },
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: const Text('Mark Done'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.mediumRadius,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: SizedBox(
                        height: AppTouchTargets.elderly,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Haptics.lightImpact();
                                  Navigator.pop(context);
                                  widget.onSnooze?.call();
                                },
                          icon: const Icon(Icons.snooze),
                          label: const Text('Snooze'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            side: const BorderSide(color: Colors.blue),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.mediumRadius,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceNotePlayer extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;

  const _VoiceNotePlayer({
    required this.isPlaying,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 48.r,
            height: 48.r,
            decoration: BoxDecoration(
              color: colorScheme.secondary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () {
                Haptics.lightImpact();
                onPlayPause();
              },
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: colorScheme.onSecondary,
                size: 24.r,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voice Message',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
                Text(
                  isPlaying ? 'Playing...' : 'Tap to play',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSecondaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.mic,
            color: colorScheme.onSecondaryContainer.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}
