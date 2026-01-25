import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_config.dart';
import '../../core/constants/app_spacing.dart';

/// A large, prominent SOS button with long-press activation.
/// Features visual countdown, haptic feedback, and accessibility support.
class SOSButton extends StatefulWidget {
  const SOSButton({
    super.key,
    required this.onActivated,
    this.onCancelled,
    this.size = AppTouchTargets.sosButton,
    this.holdDuration = const Duration(
      milliseconds: AppConfig.sosLongPressDurationMs,
    ),
  });

  final VoidCallback onActivated;
  final VoidCallback? onCancelled;
  final double size;
  final Duration holdDuration;

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isHolding = false;
  Timer? _hapticTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        widget.onActivated();
        _reset();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _hapticTimer?.cancel();
    super.dispose();
  }

  void _startHold() {
    setState(() {
      _isHolding = true;
    });
    HapticFeedback.mediumImpact();
    _animationController.forward();

    // Periodic haptic feedback during hold
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_isHolding) {
        HapticFeedback.selectionClick();
      }
    });
  }

  void _cancelHold() {
    if (_isHolding) {
      _reset();
      widget.onCancelled?.call();
    }
  }

  void _reset() {
    setState(() {
      _isHolding = false;
    });
    _animationController.reset();
    _hapticTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'SOS Emergency Button. Press and hold for 3 seconds to activate.',
      button: true,
      child: GestureDetector(
        onLongPressStart: (_) => _startHold(),
        onLongPressEnd: (_) => _cancelHold(),
        onLongPressCancel: () => _cancelHold(),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isHolding
                    ? AppColors.sosRedDark
                    : AppColors.sosRed,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.sosRed.withValues(alpha: 0.4),
                    blurRadius: _isHolding ? 20 : 10,
                    spreadRadius: _isHolding ? 5 : 2,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Progress indicator
                  if (_isHolding)
                    SizedBox(
                      width: widget.size - 16,
                      height: widget.size - 16,
                      child: CircularProgressIndicator(
                        value: _animationController.value,
                        strokeWidth: 6,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  // SOS text
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.warning_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      if (!_isHolding)
                        Text(
                          'Hold',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A confirmation dialog for SOS with countdown timer
class SOSConfirmationDialog extends StatefulWidget {
  const SOSConfirmationDialog({
    super.key,
    required this.onConfirm,
    required this.onCancel,
    this.countdownSeconds = AppConfig.sosCancellationWindowSeconds,
  });

  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final int countdownSeconds;

  @override
  State<SOSConfirmationDialog> createState() => _SOSConfirmationDialogState();
}

class _SOSConfirmationDialogState extends State<SOSConfirmationDialog> {
  late int _remainingSeconds;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.countdownSeconds;
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 3) {
        HapticFeedback.heavyImpact();
      }

      if (_remainingSeconds <= 0) {
        timer.cancel();
        widget.onConfirm();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: AppColors.errorLight,
      title: Row(
        children: [
          Icon(
            Icons.warning_rounded,
            color: AppColors.error,
            size: 32,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'SOS Activated',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Emergency contacts will be notified in',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.error,
            ),
            child: Center(
              child: Text(
                '$_remainingSeconds',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Tap Cancel if you\'re okay',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: AppTouchTargets.elderly,
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _countdownTimer?.cancel();
              widget.onCancel();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.largeRadius,
              ),
            ),
            child: Text(
              'CANCEL - I\'m Okay',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
