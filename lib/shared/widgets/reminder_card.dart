import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/custom_icons.dart';
import '../../core/utils/category_inference.dart';
import '../../core/utils/haptics.dart';

/// A card displaying a reminder with status indicator and actions.
/// Features gradient backgrounds, category icons, and press animations.
class ReminderCard extends StatefulWidget {
  const ReminderCard({
    super.key,
    required this.title,
    required this.time,
    required this.status,
    this.subtitle,
    this.hasVoiceNote = false,
    this.onTap,
    this.onMarkDone,
    this.onSnooze,
    this.priority = ReminderPriority.normal,
    this.enableAnimations = true,
  });

  final String title;
  final String time;
  final ReminderStatus status;
  final String? subtitle;
  final bool hasVoiceNote;
  final VoidCallback? onTap;
  final VoidCallback? onMarkDone;
  final VoidCallback? onSnooze;
  final ReminderPriority priority;
  final bool enableAnimations;

  @override
  State<ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<ReminderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.enableAnimations || _shouldReduceMotion()) return;
    setState(() => _isPressed = true);
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.enableAnimations || _shouldReduceMotion()) return;
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

  void _handleTapCancel() {
    if (!widget.enableAnimations || _shouldReduceMotion()) return;
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

  bool _shouldReduceMotion() {
    return MediaQuery.of(context).disableAnimations;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final category = CategoryInference.inferCategory(widget.title);

    final (statusColor, statusIcon, statusLabel) = switch (widget.status) {
      ReminderStatus.pending => (
          AppColors.warning,
          AppIcons.pending,
          'Pending',
        ),
      ReminderStatus.completed => (
          AppColors.success,
          AppIcons.completed,
          'Done',
        ),
      ReminderStatus.missed => (
          AppColors.error,
          AppIcons.missed,
          'Missed',
        ),
      ReminderStatus.snoozed => (
          AppColors.info,
          AppIcons.snoozed,
          'Snoozed',
        ),
    };

    final gradient = AppColors.getStatusGradient(
      widget.status.name,
      isDark: isDark,
    );

    final borderColor = AppColors.getStatusBorderColor(widget.status.name);

    final priorityIndicator = widget.priority == ReminderPriority.high
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'HIGH',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        : null;

    Widget cardContent = GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: () {
        Haptics.selectionClick();
        widget.onTap?.call();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.enableAnimations && !_shouldReduceMotion()
                ? _scaleAnimation.value
                : 1.0,
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: AppRadius.largeRadius,
            border: Border(
              left: BorderSide(
                color: borderColor,
                width: 6,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: _isPressed ? 0.3 : 0.15),
                blurRadius: _isPressed ? 12 : 8,
                offset: Offset(0, _isPressed ? 6 : 4),
              ),
            ],
          ),
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Category icon with colored background
                    CategoryIconWidget(
                      category: category,
                      size: 48.r,
                      iconSize: 24.r,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Title and time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    decoration:
                                        widget.status == ReminderStatus.completed
                                            ? TextDecoration.lineThrough
                                            : null,
                                    color: isDark ? Colors.white : null,
                                  ),
                                ),
                              ),
                              if (priorityIndicator != null) priorityIndicator,
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                statusIcon,
                                color: statusColor,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.time,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Voice note indicator
                    if (widget.hasVoiceNote)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          AppIcons.voiceNote,
                          color: colorScheme.onPrimaryContainer,
                          size: 20,
                        ),
                      ),
                  ],
                ),
                // Subtitle if present
                if (widget.subtitle != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    widget.subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? Colors.white70
                          : colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // Action buttons for pending reminders
                if (widget.status == ReminderStatus.pending &&
                    (widget.onMarkDone != null || widget.onSnooze != null)) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      if (widget.onMarkDone != null)
                        Expanded(
                          child: _ActionButton(
                            onPressed: widget.onMarkDone!,
                            icon: AppIcons.done,
                            label: 'Done',
                            color: AppColors.success,
                            gradient: AppColors.successButtonGradient,
                          ),
                        ),
                      if (widget.onMarkDone != null && widget.onSnooze != null)
                        const SizedBox(width: AppSpacing.sm),
                      if (widget.onSnooze != null)
                        Expanded(
                          child: _ActionButton(
                            onPressed: widget.onSnooze!,
                            icon: AppIcons.snooze,
                            label: 'Snooze',
                            color: AppColors.info,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      label:
          'Reminder: ${widget.title} at ${widget.time}, Status: $statusLabel${widget.hasVoiceNote ? ', has voice note' : ''}',
      button: true,
      child: cardContent,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
    this.gradient,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color color;
  final LinearGradient? gradient;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppTouchTargets.minimum,
      child: gradient != null
          ? Container(
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: AppRadius.mediumRadius,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Haptics.mediumImpact();
                    onPressed();
                  },
                  borderRadius: AppRadius.mediumRadius,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 20, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : ElevatedButton.icon(
              onPressed: () {
                Haptics.mediumImpact();
                onPressed();
              },
              icon: Icon(icon, size: 20),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.mediumRadius,
                ),
              ),
            ),
    );
  }
}

/// Large reminder button for dependent home screen
class LargeReminderButton extends StatefulWidget {
  const LargeReminderButton({
    super.key,
    required this.title,
    required this.time,
    required this.onTap,
    this.hasVoiceNote = false,
    this.isUrgent = false,
    this.enableAnimations = true,
  });

  final String title;
  final String time;
  final VoidCallback onTap;
  final bool hasVoiceNote;
  final bool isUrgent;
  final bool enableAnimations;

  @override
  State<LargeReminderButton> createState() => _LargeReminderButtonState();
}

class _LargeReminderButtonState extends State<LargeReminderButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  bool _shouldReduceMotion() {
    return MediaQuery.of(context).disableAnimations;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = CategoryInference.inferCategory(widget.title);

    return Semantics(
      label:
          'Reminder: ${widget.title} at ${widget.time}${widget.isUrgent ? ', urgent' : ''}',
      button: true,
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.enableAnimations && !_shouldReduceMotion()) {
            _pressController.forward();
          }
        },
        onTapUp: (_) {
          if (widget.enableAnimations && !_shouldReduceMotion()) {
            _pressController.reverse();
          }
        },
        onTapCancel: () {
          if (widget.enableAnimations && !_shouldReduceMotion()) {
            _pressController.reverse();
          }
        },
        onTap: () {
          Haptics.mediumImpact();
          widget.onTap();
        },
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.enableAnimations && !_shouldReduceMotion()
                  ? _scaleAnimation.value
                  : 1.0,
              child: child,
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: widget.isUrgent
                  ? AppColors.missedGradient
                  : AppIcons.getCategoryGradient(category),
              borderRadius: AppRadius.xlargeRadius,
              border: Border.all(
                color: widget.isUrgent
                    ? AppColors.error
                    : AppIcons.getCategoryColor(category),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: (widget.isUrgent
                          ? AppColors.error
                          : AppIcons.getCategoryColor(category))
                      .withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Category Icon
                Container(
                  width: 56.r,
                  height: 56.r,
                  decoration: BoxDecoration(
                    color: widget.isUrgent
                        ? AppColors.error
                        : AppIcons.getCategoryColor(category),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.hasVoiceNote
                        ? AppIcons.voiceNote
                        : AppIcons.getCategoryIcon(category),
                    color: Colors.white,
                    size: 28.r,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: widget.isUrgent
                              ? AppColors.error
                              : AppIcons.getCategoryColor(category),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.time,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: widget.isUrgent
                              ? AppColors.error.withValues(alpha: 0.8)
                              : AppIcons.getCategoryColor(category)
                                  .withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  AppIcons.forward,
                  size: 24,
                  color: widget.isUrgent
                      ? AppColors.error
                      : AppIcons.getCategoryColor(category),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum ReminderStatus {
  pending,
  completed,
  missed,
  snoozed,
}

enum ReminderPriority {
  normal,
  high,
}
