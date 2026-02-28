import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../shared/widgets/redesign_ui.dart';

/// Full-screen reminder alert for dependents
class ReminderAlertScreen extends StatefulWidget {
  final String instanceId;

  const ReminderAlertScreen({super.key, required this.instanceId});

  @override
  State<ReminderAlertScreen> createState() => _ReminderAlertScreenState();
}

class _ReminderAlertScreenState extends State<ReminderAlertScreen> {
  final _reminderApi = getIt<ReminderApi>();
  final _reminderInstanceApi = getIt<ReminderInstanceApi>();
  final AudioPlayer _player = AudioPlayer();

  ReminderInstanceData? _instance;
  ReminderData? _reminder;
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
      // Load instance directly from API
      _instance = await _reminderInstanceApi.getInstance(widget.instanceId);

      if (_instance != null) {
        _reminder = await _reminderApi.getReminder(_instance!.reminderId);

        // Auto-play voice note if available
        if (_reminder?.voiceNoteUrl != null) {
          _playVoiceNote();
        }
      }
    } on ApiException catch (e) {
      debugPrint('Error loading reminder: ${e.message}');
    } catch (e) {
      debugPrint('Error loading reminder: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _playVoiceNote() async {
    if (_reminder?.voiceNoteUrl == null) return;

    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.play(UrlSource(_reminder!.voiceNoteUrl!));
      }
    } catch (e) {
      debugPrint('Error playing voice note: $e');
    }
  }

  Future<void> _markDone() async {
    Haptics.heavyImpact();

    try {
      await _reminderInstanceApi.markCompleted(widget.instanceId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Great job! Reminder completed.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go(AppRoutes.dependentHome);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: AppColors.error,
          ),
        );
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
    Haptics.mediumImpact();

    try {
      final snoozeUntil = DateTime.now().toUtc().add(
        const Duration(minutes: 10),
      );
      await _reminderInstanceApi.snooze(widget.instanceId, snoozeUntil);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Snoozed for 10 minutes')));
        context.go(AppRoutes.dependentHome);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: AppColors.error,
          ),
        );
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
        body: RedesignBackground(
          child: const Center(child: CircularProgressIndicator()),
        ),
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

    final accentColor = _reminder!.priority == 'high'
        ? AppColors.error
        : colorScheme.primary;

    return Scaffold(
      body: RedesignBackground(
        child: SafeArea(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => context.go(AppRoutes.dependentHome),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Reminder Alert',
                        style: theme.textTheme.labelLarge?.copyWith(
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        GlassCard(
                          margin: EdgeInsets.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: AppSpacing.lg,
                          ),
                          child: Column(
                            children: [
                              Text(
                                _instance != null
                                    ? DateFormat.jm().format(
                                        _instance!.scheduledTime.toLocal(),
                                      )
                                    : '--:--',
                                style: theme.textTheme.displayMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Morning Session',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: accentColor,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          _reminder!.title,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_reminder!.description != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _reminder!.description!,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (_reminder!.voiceNoteUrl != null) ...[
                          const SizedBox(height: AppSpacing.xl),
                          _VoiceNotePlayer(
                            isPlaying: _isPlaying,
                            onPlayPause: _playVoiceNote,
                            accentColor: accentColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                GradientPrimaryButton(
                  label: 'Done',
                  icon: Icons.check_circle,
                  onPressed: _markDone,
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.tonal(
                  onPressed: _snooze,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: const Text('Remind me in 10 minutes'),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
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
        color: theme.colorScheme.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
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
