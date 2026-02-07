import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_config.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/custom_icons.dart';

/// A large, prominent SOS button with long-press activation.
/// Features visual countdown, haptic feedback, pulse animation, and accessibility support.
class SOSButton extends StatefulWidget {
  const SOSButton({
    super.key,
    required this.onActivated,
    this.onCancelled,
    this.size = AppTouchTargets.sosButton,
    this.holdDuration = const Duration(
      milliseconds: AppConfig.sosLongPressDurationMs,
    ),
    this.enablePulseAnimation = true,
  });

  final VoidCallback onActivated;
  final VoidCallback? onCancelled;
  final double size;
  final Duration holdDuration;
  final bool enablePulseAnimation;

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton>
    with TickerProviderStateMixin {
  late AnimationController _holdController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isHolding = false;
  Timer? _hapticTimer;

  @override
  void initState() {
    super.initState();

    // Hold progress animation
    _holdController = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    );

    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticFeedback.heavyImpact();
        widget.onActivated();
        _reset();
      }
    });

    // Pulse animation (subtle breathing effect)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Start pulse animation if enabled and not in reduced motion mode
    if (widget.enablePulseAnimation) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _holdController.dispose();
    _pulseController.dispose();
    _hapticTimer?.cancel();
    super.dispose();
  }

  bool _shouldReduceMotion() {
    return MediaQuery.of(context).disableAnimations;
  }

  void _startHold() {
    setState(() {
      _isHolding = true;
    });
    HapticFeedback.mediumImpact();
    _holdController.forward();

    // Stop pulse animation during hold
    _pulseController.stop();

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
    _holdController.reset();
    _hapticTimer?.cancel();

    // Resume pulse animation
    if (widget.enablePulseAnimation && !_shouldReduceMotion()) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = _shouldReduceMotion();

    // Stop pulse animation if reduce motion is enabled
    if (reduceMotion && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }

    return Semantics(
      label: 'SOS Emergency Button. Press and hold for 3 seconds to activate.',
      button: true,
      child: GestureDetector(
        onLongPressStart: (_) => _startHold(),
        onLongPressEnd: (_) => _cancelHold(),
        onLongPressCancel: () => _cancelHold(),
        child: AnimatedBuilder(
          animation: Listenable.merge([_holdController, _pulseAnimation]),
          builder: (context, child) {
            final pulseScale = widget.enablePulseAnimation && !reduceMotion && !_isHolding
                ? _pulseAnimation.value
                : 1.0;

            return Transform.scale(
              scale: pulseScale,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.8,
                    colors: _isHolding
                        ? [
                            AppColors.sosRedDark,
                            AppColors.sosRedDark.withValues(alpha: 0.9),
                          ]
                        : [
                            AppColors.sosRed.withValues(alpha: 0.9),
                            AppColors.sosRed,
                          ],
                  ),
                  boxShadow: [
                    // Outer glow
                    BoxShadow(
                      color: AppColors.sosRed.withValues(
                        alpha: _isHolding ? 0.6 : 0.4,
                      ),
                      blurRadius: _isHolding ? 30 : 20,
                      spreadRadius: _isHolding ? 8 : 4,
                    ),
                    // Inner shadow for depth
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
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
                          value: _holdController.value,
                          strokeWidth: 6,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    // SOS content
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          AppIcons.sos,
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

class _SOSConfirmationDialogState extends State<SOSConfirmationDialog>
    with SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  Timer? _countdownTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.countdownSeconds;
    _startCountdown();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
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
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return AlertDialog(
      backgroundColor: AppColors.errorLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: Row(
        children: [
          Icon(
            AppIcons.sos,
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
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: reduceMotion ? 1.0 : _pulseAnimation.value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.error,
                        AppColors.errorDark,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.error.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                    ],
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
              );
            },
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
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.successButtonGradient,
              borderRadius: AppRadius.largeRadius,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _countdownTimer?.cancel();
                  widget.onCancel();
                },
                borderRadius: AppRadius.largeRadius,
                child: Center(
                  child: Text(
                    'CANCEL - I\'m Okay',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
