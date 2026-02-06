import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A swipe-to-confirm button for logout action.
/// User must drag the thumb from left to right past a threshold to trigger the action.
class SwipeToLogoutButton extends StatefulWidget {
  /// Callback when the swipe is completed
  final VoidCallback onSwipeComplete;

  /// Optional label text (defaults to "Swipe to Logout")
  final String label;

  /// Height of the button
  final double height;

  const SwipeToLogoutButton({
    super.key,
    required this.onSwipeComplete,
    this.label = 'Swipe to Logout',
    this.height = 60,
  });

  @override
  State<SwipeToLogoutButton> createState() => _SwipeToLogoutButtonState();
}

class _SwipeToLogoutButtonState extends State<SwipeToLogoutButton> {
  double _dragPosition = 0;
  bool _isDragging = false;

  // Thumb size
  static const double _thumbSize = 50;
  // Threshold percentage to trigger action (80%)
  static const double _triggerThreshold = 0.8;
  // Padding inside the track
  static const double _trackPadding = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final maxDrag = trackWidth - _thumbSize - (_trackPadding * 2);
        final currentProgress = maxDrag > 0 ? _dragPosition / maxDrag : 0.0;

        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: colorScheme.errorContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(widget.height / 2),
            border: Border.all(
              color: colorScheme.error.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              // Progress fill
              AnimatedContainer(
                duration: const Duration(milliseconds: 50),
                width: _dragPosition + _thumbSize + _trackPadding,
                height: widget.height,
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.2 + (currentProgress * 0.3)),
                  borderRadius: BorderRadius.circular(widget.height / 2),
                ),
              ),

              // Label text (fades as thumb moves)
              Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 100),
                  opacity: (1 - currentProgress).clamp(0.3, 1.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: _thumbSize + _trackPadding),
                      Icon(
                        Icons.arrow_forward,
                        color: colorScheme.error.withValues(alpha: 0.7),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: _thumbSize),
                    ],
                  ),
                ),
              ),

              // Draggable thumb
              Positioned(
                left: _trackPadding + _dragPosition,
                top: _trackPadding,
                child: GestureDetector(
                  onHorizontalDragStart: (_) {
                    setState(() => _isDragging = true);
                    HapticFeedback.lightImpact();
                  },
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _dragPosition += details.delta.dx;
                      _dragPosition = _dragPosition.clamp(0.0, maxDrag);
                    });
                  },
                  onHorizontalDragEnd: (_) {
                    final threshold = maxDrag * _triggerThreshold;

                    if (_dragPosition >= threshold) {
                      HapticFeedback.heavyImpact();
                      widget.onSwipeComplete();
                    }

                    setState(() {
                      _isDragging = false;
                      _dragPosition = 0;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: _thumbSize,
                    height: widget.height - (_trackPadding * 2),
                    decoration: BoxDecoration(
                      color: _isDragging
                          ? colorScheme.error
                          : colorScheme.error.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular((widget.height - (_trackPadding * 2)) / 2),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.error.withValues(alpha: _isDragging ? 0.4 : 0.2),
                          blurRadius: _isDragging ? 8 : 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      currentProgress >= _triggerThreshold
                          ? Icons.logout
                          : Icons.chevron_right,
                      color: colorScheme.onError,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
