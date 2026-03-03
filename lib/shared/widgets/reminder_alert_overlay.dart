import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/di/injection.dart';
import '../../core/utils/haptics.dart';
import '../../data/datasources/remote/remote.dart';

/// A non-dismissible bottom sheet overlay that appears when a reminder alarm fires.
///
/// Covers ~75% of the screen, shows reminder details, and provides
/// Done/Snooze actions that stop the alarm sound.
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
  final AudioPlayer _voicePlayer = AudioPlayer();

  ReminderInstanceData? _instance;
  ReminderData? _reminder;
  bool _isLoading = true;
  bool _isActioning = false;
  bool _isPlayingVoice = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupVoicePlayer();
  }

  @override
  void dispose() {
    _voicePlayer.dispose();
    super.dispose();
  }

  void _setupVoicePlayer() {
    _voicePlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingVoice = state == PlayerState.playing;
        });
      }
    });
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

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _playVoiceNote() async {
    final url = _reminder?.voiceNoteUrl ?? _instance?.voiceNoteUrl;
    if (url == null) return;

    try {
      if (_isPlayingVoice) {
        await _voicePlayer.pause();
      } else {
        await _voicePlayer.play(UrlSource(url));
      }
    } catch (e) {
      debugPrint('ReminderAlertOverlay: Error playing voice note: $e');
    }
  }

  Future<void> _markDone() async {
    if (_isActioning) return;
    setState(() => _isActioning = true);
    Haptics.heavyImpact();

    try {
      await _voicePlayer.stop();
      await _reminderInstanceApi.markCompleted(widget.instanceId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Great job! Reminder completed.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      widget.onDismiss();
    } catch (e) {
      debugPrint('ReminderAlertOverlay: Error marking done: $e');
      if (mounted) {
        setState(() => _isActioning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _snooze() async {
    if (_isActioning) return;
    setState(() => _isActioning = true);
    Haptics.mediumImpact();

    try {
      await _voicePlayer.stop();
      final snoozeUntil = DateTime.now().toUtc().add(const Duration(minutes: 10));
      await _reminderInstanceApi.snooze(widget.instanceId, snoozeUntil);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Snoozed for 10 minutes')),
        );
      }
      widget.onDismiss();
    } catch (e) {
      debugPrint('ReminderAlertOverlay: Error snoozing: $e');
      if (mounted) {
        setState(() => _isActioning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FractionallySizedBox(
      heightFactor: 0.75,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(theme, colorScheme),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme colorScheme) {
    final title = _reminder?.title ?? _instance?.reminderTitle ?? 'Reminder';
    final description = _reminder?.description ?? _instance?.reminderDescription;
    final voiceNoteUrl = _reminder?.voiceNoteUrl ?? _instance?.voiceNoteUrl;
    final priority = _reminder?.priority ?? _instance?.priority ?? 'normal';
    final isHighPriority = priority == 'high';

    final accentColor = isHighPriority ? AppColors.error : colorScheme.primary;

    return SafeArea(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          children: [
            // Drag handle indicator
            Container(
              width: 40.w,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Priority badge
            if (isHighPriority)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: AppRadius.smallRadius,
                  border: Border.all(color: AppColors.error),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.priority_high, color: AppColors.error, size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'High Priority',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            const Spacer(),

            // Reminder icon
            Container(
              width: 100.r,
              height: 100.r,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.notifications_active,
                color: Colors.white,
                size: 56.r,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Schedule time
            if (_instance != null)
              Text(
                DateFormat.jm().format(_instance!.scheduledTime.toLocal()),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: accentColor,
                ),
              ),
            const SizedBox(height: AppSpacing.sm),

            // Title
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            // Description
            if (description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                description,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Voice note player
            if (voiceNoteUrl != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildVoiceNotePlayer(theme, accentColor),
            ],

            const Spacer(),

            // Action buttons
            SizedBox(
              width: double.infinity,
              height: AppTouchTargets.elderly,
              child: ElevatedButton.icon(
                onPressed: _isActioning ? null : _markDone,
                icon: _isActioning
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : const Icon(Icons.check, size: 28),
                label: Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _isActioning ? null : Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.largeRadius,
                  ),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: AppTouchTargets.elderly,
              child: OutlinedButton.icon(
                onPressed: _isActioning ? null : _snooze,
                icon: const Icon(Icons.snooze, size: 28),
                label: const Text(
                  'Remind me in 10 minutes',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.largeRadius,
                  ),
                  side: BorderSide(color: colorScheme.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceNotePlayer(ThemeData theme, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48.r,
            height: 48.r,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _playVoiceNote,
              icon: Icon(
                _isPlayingVoice ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 28.r,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Voice Message',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _isPlayingVoice ? 'Playing...' : 'Tap to play',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
    );
  }
}
