import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/app_spacing.dart';

/// Widget for recording and playing back voice notes
class VoiceRecorderWidget extends StatefulWidget {
  final String? voiceNotePath; // Local file path for new recordings
  final String? voiceNoteUrl; // Remote URL for existing recordings
  final ValueChanged<String> onRecordingComplete;
  final VoidCallback onDelete;

  const VoiceRecorderWidget({
    super.key,
    this.voiceNotePath,
    this.voiceNoteUrl,
    required this.onRecordingComplete,
    required this.onDelete,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _isRecording = false;
  bool _isPlaying = false;
  int _recordingDuration = 0;
  Timer? _durationTimer;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
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

    _player.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _playbackPosition = position;
        });
      }
    });

    _player.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _playbackDuration = duration;
        });
      }
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playbackPosition = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    // Check permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required to record voice notes'),
          ),
        );
      }
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/voice_${const Uuid().v4()}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      HapticFeedback.mediumImpact();

      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_recordingDuration >= AppConfig.maxVoiceNoteDurationSeconds) {
          _stopRecording();
          return;
        }

        if (mounted) {
          setState(() {
            _recordingDuration++;
          });
        }
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _durationTimer?.cancel();

    try {
      final path = await _recorder.stop();

      setState(() {
        _isRecording = false;
      });

      HapticFeedback.mediumImpact();

      if (path != null) {
        widget.onRecordingComplete(path);
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _playRecording() async {
    final hasLocalPath = widget.voiceNotePath != null;
    final hasUrl = widget.voiceNoteUrl != null;

    if (!hasLocalPath && !hasUrl) return;

    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        // Prefer local path if available, otherwise use URL
        if (hasLocalPath) {
          await _player.play(DeviceFileSource(widget.voiceNotePath!));
        } else {
          await _player.play(UrlSource(widget.voiceNoteUrl!));
        }
      }
    } catch (e) {
      debugPrint('Error playing recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing recording: $e')),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isRecording) {
      return _buildRecordingState();
    }

    // Show playback if either local path or URL exists
    if (widget.voiceNotePath != null || widget.voiceNoteUrl != null) {
      return _buildPlaybackState();
    }

    return _buildIdleState();
  }

  Widget _buildIdleState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Add a voice message',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _startRecording,
            icon: const Icon(Icons.mic, size: 18),
            label: const Text('Record'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingState() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        border: Border.all(color: AppColors.error, width: 2),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Recording...',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _formatDuration(_recordingDuration),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Max: ${_formatDuration(AppConfig.maxVoiceNoteDurationSeconds)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton.icon(
            onPressed: _stopRecording,
            icon: const Icon(Icons.stop),
            label: const Text('Stop Recording'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        border: Border.all(color: colorScheme.primary),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _playRecording,
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voice Note',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_playbackDuration.inSeconds > 0)
                      Text(
                        '${_formatDuration(_playbackPosition.inSeconds)} / ${_formatDuration(_playbackDuration.inSeconds)}',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  _player.stop();
                  widget.onDelete();
                },
                icon: Icon(
                  Icons.delete,
                  color: colorScheme.error,
                ),
                tooltip: 'Delete voice note',
              ),
            ],
          ),
          if (_playbackDuration.inSeconds > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(
              value: _playbackDuration.inSeconds > 0
                  ? _playbackPosition.inSeconds / _playbackDuration.inSeconds
                  : 0,
              backgroundColor: colorScheme.surface,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ],
        ],
      ),
    );
  }
}
