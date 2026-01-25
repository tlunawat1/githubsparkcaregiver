import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../data/datasources/local/database.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../shared/widgets/accessible_button.dart';

/// Full-screen reminder alert for dependents
class ReminderAlertScreen extends StatefulWidget {
  final String instanceId;

  const ReminderAlertScreen({
    super.key,
    required this.instanceId,
  });

  @override
  State<ReminderAlertScreen> createState() => _ReminderAlertScreenState();
}

class _ReminderAlertScreenState extends State<ReminderAlertScreen> {
  final _reminderRepository = getIt<ReminderRepository>();
  final AudioPlayer _player = AudioPlayer();

  ReminderInstance? _instance;
  Reminder? _reminder;
  bool _isLoading = true;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupPlayer();
  }

  void _setupPlayer() {
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

  Future<void> _loadData() async {
    try {
      // For MVP, we'll need to get the instance from the database
      // This is a simplified approach - in production you'd query by instance ID
      final userId = await getIt<SettingsRepository>().getCurrentUserId();
      if (userId != null) {
        final instances =
            await _reminderRepository.getTodayInstancesForDependent(userId);
        _instance = instances.firstWhere(
          (i) => i.id == widget.instanceId,
          orElse: () => instances.first,
        );

        if (_instance != null) {
          _reminder =
              await _reminderRepository.getReminderById(_instance!.reminderId);

          // Auto-play voice note if available
          if (_reminder?.voiceNotePath != null) {
            _playVoiceNote();
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading reminder: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _playVoiceNote() async {
    if (_reminder?.voiceNotePath == null) return;

    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.play(DeviceFileSource(_reminder!.voiceNotePath!));
      }
    } catch (e) {
      debugPrint('Error playing voice note: $e');
    }
  }

  Future<void> _markDone() async {
    HapticFeedback.heavyImpact();

    try {
      await _reminderRepository.markInstanceCompleted(widget.instanceId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Great job! Reminder completed.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go(AppRoutes.dependentHome);
      }
    } catch (e) {
      if (mounted) {
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
    HapticFeedback.mediumImpact();

    try {
      final snoozeUntil = DateTime.now().add(const Duration(minutes: 10));
      await _reminderRepository.snoozeInstance(widget.instanceId, snoozeUntil);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Snoozed for 10 minutes'),
          ),
        );
        context.go(AppRoutes.dependentHome);
      }
    } catch (e) {
      if (mounted) {
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

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.primaryContainer,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_reminder == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64),
              const SizedBox(height: AppSpacing.md),
              const Text('Reminder not found'),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.dependentHome),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final isHighPriority = _reminder!.priority == 'high';
    final backgroundColor =
        isHighPriority ? AppColors.errorLight : colorScheme.primaryContainer;
    final accentColor =
        isHighPriority ? AppColors.error : colorScheme.primary;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            children: [
              // Back button
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: () => context.go(AppRoutes.dependentHome),
                  icon: const Icon(Icons.close),
                  iconSize: 32,
                ),
              ),
              const Spacer(),
              // Reminder icon
              Container(
                width: 120,
                height: 120,
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
                  _reminder!.voiceNotePath != null
                      ? Icons.mic
                      : Icons.notifications_active,
                  color: Colors.white,
                  size: 64,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Time
              Text(
                _instance != null
                    ? DateFormat.jm().format(_instance!.scheduledTime)
                    : '',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: accentColor,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Title
              Text(
                _reminder!.title,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              // Description
              if (_reminder!.description != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _reminder!.description!,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              // Voice note player
              if (_reminder!.voiceNotePath != null) ...[
                const SizedBox(height: AppSpacing.xl),
                _VoiceNotePlayer(
                  isPlaying: _isPlaying,
                  onPlayPause: _playVoiceNote,
                  accentColor: accentColor,
                ),
              ],
              const Spacer(),
              // Action buttons
              AccessibleButton(
                onPressed: _markDone,
                label: 'Done',
                icon: Icons.check,
                size: AccessibleButtonSize.xlarge,
                backgroundColor: AppColors.success,
              ),
              const SizedBox(height: AppSpacing.md),
              AccessibleOutlinedButton(
                onPressed: _snooze,
                label: 'Remind me in 10 minutes',
                icon: Icons.snooze,
                size: AccessibleButtonSize.large,
              ),
              const SizedBox(height: AppSpacing.xl),
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
  final Color accentColor;

  const _VoiceNotePlayer({
    required this.isPlaying,
    required this.onPlayPause,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: onPlayPause,
              icon: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Voice Message',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                isPlaying ? 'Playing...' : 'Tap to play',
                style: theme.textTheme.bodyMedium?.copyWith(
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
