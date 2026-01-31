import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';

/// Status of a reminder instance
enum ReminderInstanceStatus {
  pending,
  completed,
  missed,
  snoozed,
}

/// A square-ish button widget for displaying reminder instances.
/// Features one-tap completion, color-coded status, and a details button.
class ReminderButton extends StatelessWidget {
  const ReminderButton({
    super.key,
    required this.title,
    required this.time,
    required this.status,
    this.hasVoiceNote = false,
    this.onTap,
    this.onDetailsTap,
    this.isLoading = false,
  });

  final String title;
  final String time;
  final ReminderInstanceStatus status;
  final bool hasVoiceNote;
  final VoidCallback? onTap;
  final VoidCallback? onDetailsTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (backgroundColor, borderColor, textColor) = switch (status) {
      ReminderInstanceStatus.pending => (
          AppColors.warningLight,
          AppColors.warning,
          AppColors.warning,
        ),
      ReminderInstanceStatus.completed => (
          AppColors.successLight,
          AppColors.success,
          AppColors.success,
        ),
      ReminderInstanceStatus.missed => (
          AppColors.errorLight,
          AppColors.error,
          AppColors.error,
        ),
      ReminderInstanceStatus.snoozed => (
          Colors.blue.shade50,
          Colors.blue,
          Colors.blue,
        ),
    };

    final isActionable = status == ReminderInstanceStatus.pending ||
        status == ReminderInstanceStatus.snoozed;

    return Semantics(
      label:
          'Reminder: $title at $time, Status: ${status.name}${hasVoiceNote ? ', has voice note' : ''}',
      button: true,
      child: Material(
        color: backgroundColor,
        borderRadius: AppRadius.largeRadius,
        child: InkWell(
          onTap: isLoading
              ? null
              : isActionable
                  ? () {
                      HapticFeedback.mediumImpact();
                      onTap?.call();
                    }
                  : null,
          borderRadius: AppRadius.largeRadius,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: AppRadius.largeRadius,
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Stack(
              children: [
                // Details button (top-right)
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: isLoading
                        ? null
                        : () {
                            HapticFeedback.lightImpact();
                            onDetailsTap?.call();
                          },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: borderColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.help_outline,
                        size: 18,
                        color: borderColor,
                      ),
                    ),
                  ),
                ),
                // Main content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Voice note indicator
                    if (hasVoiceNote)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Row(
                          children: [
                            Icon(Icons.mic, size: 14, color: textColor),
                            const SizedBox(width: 4),
                            Text(
                              'Voice note',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Time
                    Text(
                      time,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Title
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: textColor.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                        decoration: status == ReminderInstanceStatus.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Status indicator
                    if (isLoading)
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(textColor),
                        ),
                      )
                    else
                      _buildStatusChip(theme, textColor),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme, Color textColor) {
    final (icon, label) = switch (status) {
      ReminderInstanceStatus.pending => (Icons.touch_app, 'Tap to complete'),
      ReminderInstanceStatus.completed => (Icons.check_circle, 'Done'),
      ReminderInstanceStatus.missed => (Icons.error, 'Missed'),
      ReminderInstanceStatus.snoozed => (Icons.snooze, 'Snoozed'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: textColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
