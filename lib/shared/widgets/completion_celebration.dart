import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/haptics.dart';

/// A widget that shows a celebration animation when a task is completed.
/// Includes confetti, scale animation, and haptic feedback.
class CompletionCelebration extends StatefulWidget {
  const CompletionCelebration({
    super.key,
    required this.child,
    this.onCelebrationComplete,
    this.message = 'Great job!',
    this.autoPlay = true,
    this.duration = const Duration(milliseconds: 2000),
  });

  final Widget child;
  final VoidCallback? onCelebrationComplete;
  final String message;
  final bool autoPlay;
  final Duration duration;

  @override
  State<CompletionCelebration> createState() => CompletionCelebrationState();
}

class CompletionCelebrationState extends State<CompletionCelebration>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _scaleController;
  late AnimationController _messageController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _messageAnimation;
  bool _showMessage = false;

  @override
  void initState() {
    super.initState();

    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 500),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
      ),
    );

    _messageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _messageAnimation = CurvedAnimation(
      parent: _messageController,
      curve: Curves.easeOutBack,
    );

    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        celebrate();
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scaleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  /// Trigger the celebration animation
  void celebrate() {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    // Haptic feedback
    Haptics.heavyImpact();

    if (!reduceMotion) {
      // Play confetti
      _confettiController.play();

      // Scale animation
      _scaleController.forward().then((_) {
        _scaleController.reverse();
      });

      // Show message
      setState(() => _showMessage = true);
      _messageController.forward();
    }

    // Auto-hide message after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        setState(() => _showMessage = false);
        _messageController.reverse();
        widget.onCelebrationComplete?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Main child widget with scale animation
        AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: reduceMotion ? 1.0 : _scaleAnimation.value,
              child: child,
            );
          },
          child: widget.child,
        ),

        // Confetti
        if (!reduceMotion)
          Positioned(
            top: 0,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              maxBlastForce: 20,
              minBlastForce: 5,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.3,
              shouldLoop: false,
              colors: const [
                AppColors.success,
                AppColors.primary,
                AppColors.accent,
                AppColors.secondary,
                Colors.pink,
                Colors.orange,
              ],
            ),
          ),

        // Success message
        if (_showMessage)
          Positioned(
            top: -50,
            child: AnimatedBuilder(
              animation: _messageAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _messageAnimation.value,
                  child: Opacity(
                    opacity: _messageAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.successButtonGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.celebration_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A standalone celebration overlay that can be shown on top of any screen.
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({
    super.key,
    required this.child,
  });

  final Widget child;

  /// Show a celebration overlay
  static void show(BuildContext context, {String message = 'Great job!'}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _CelebrationOverlayWidget(
        message: message,
        onComplete: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _CelebrationOverlayWidget extends StatefulWidget {
  const _CelebrationOverlayWidget({
    required this.message,
    required this.onComplete,
  });

  final String message;
  final VoidCallback onComplete;

  @override
  State<_CelebrationOverlayWidget> createState() => _CelebrationOverlayWidgetState();
}

class _CelebrationOverlayWidgetState extends State<_CelebrationOverlayWidget>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Start celebration
    _confettiController.play();
    _fadeController.forward();
    Haptics.heavyImpact();

    // Auto dismiss after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _fadeController.reverse().then((_) {
          widget.onComplete();
        });
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _fadeController,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeController.value,
            child: Stack(
              children: [
                // Semi-transparent background
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                ),

                // Confetti
                if (!reduceMotion)
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      maxBlastForce: 30,
                      minBlastForce: 10,
                      emissionFrequency: 0.05,
                      numberOfParticles: 50,
                      gravity: 0.2,
                      shouldLoop: false,
                      colors: const [
                        AppColors.success,
                        AppColors.primary,
                        AppColors.accent,
                        AppColors.secondary,
                        Colors.pink,
                        Colors.orange,
                        Colors.yellow,
                      ],
                    ),
                  ),

                // Message
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.lg,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: AppColors.successButtonGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          widget.message,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A simple checkmark animation for inline use
class AnimatedCheckmark extends StatefulWidget {
  const AnimatedCheckmark({
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth = 3,
    this.autoPlay = true,
  });

  final double size;
  final Color? color;
  final double strokeWidth;
  final bool autoPlay;

  @override
  State<AnimatedCheckmark> createState() => AnimatedCheckmarkState();
}

class AnimatedCheckmarkState extends State<AnimatedCheckmark>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    if (widget.autoPlay) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void play() {
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.success;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Icon(
            Icons.check_circle_rounded,
            size: widget.size,
            color: color,
          ),
        );
      },
    );
  }
}
