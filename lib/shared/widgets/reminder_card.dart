import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import 'accessible_card.dart';

/// A card displaying a reminder with status indicator and actions.
class ReminderCard extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (statusColor, statusIcon, statusLabel) = switch (status) {
      ReminderStatus.pending => (
          AppColors.warning,
          Icons.schedule,
          'Pending',
        ),
      ReminderStatus.completed => (
          AppColors.success,
          Icons.check_circle,
          'Done',
        ),
      ReminderStatus.missed => (
          AppColors.error,
          Icons.error,
          'Missed',
        ),
      ReminderStatus.snoozed => (
          Colors.blue,
          Icons.snooze,
          'Snoozed',
        ),
    };

    final priorityIndicator = priority == ReminderPriority.high
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
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        : null;

    return AccessibleCard(
      onTap: onTap,
      borderColor: status == ReminderStatus.missed ? AppColors.error : null,
      borderWidth: status == ReminderStatus.missed ? 2 : 0,
      semanticLabel:
          'Reminder: $title at $time, Status: $statusLabel${hasVoiceNote ? ', has voice note' : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Status icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 24,
                ),
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
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: status == ReminderStatus.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (priorityIndicator != null) priorityIndicator,
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Voice note indicator
              if (hasVoiceNote)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mic,
                    color: colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
            ],
          ),
          // Subtitle if present
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // Action buttons for pending reminders
          if (status == ReminderStatus.pending &&
              (onMarkDone != null || onSnooze != null)) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (onMarkDone != null)
                  Expanded(
                    child: _ActionButton(
                      onPressed: onMarkDone!,
                      icon: Icons.check,
                      label: 'Done',
                      color: AppColors.success,
                    ),
                  ),
                if (onMarkDone != null && onSnooze != null)
                  const SizedBox(width: AppSpacing.sm),
                if (onSnooze != null)
                  Expanded(
                    child: _ActionButton(
                      onPressed: onSnooze!,
                      icon: Icons.snooze,
                      label: 'Snooze',
                      color: Colors.blue,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppTouchTargets.minimum,
      child: ElevatedButton.icon(
        onPressed: () {
          HapticFeedback.mediumImpact();
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
class LargeReminderButton extends StatelessWidget {
  const LargeReminderButton({
    super.key,
    required this.title,
    required this.time,
    required this.onTap,
    this.hasVoiceNote = false,
    this.isUrgent = false,
  });

  final String title;
  final String time;
  final VoidCallback onTap;
  final bool hasVoiceNote;
  final bool isUrgent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: 'Reminder: $title at $time${isUrgent ? ', urgent' : ''}',
      button: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        borderRadius: AppRadius.xlargeRadius,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: isUrgent
                ? AppColors.errorLight
                : colorScheme.primaryContainer,
            borderRadius: AppRadius.xlargeRadius,
            border: Border.all(
              color: isUrgent ? AppColors.error : colorScheme.primary,
              width: 3,
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isUrgent ? AppColors.error : colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasVoiceNote ? Icons.mic : Icons.notifications_active,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isUrgent
                            ? AppColors.error
                            : colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isUrgent
                            ? AppColors.error.withValues(alpha: 0.8)
                            : colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                Icons.arrow_forward_ios,
                size: 24,
                color: isUrgent
                    ? AppColors.error
                    : colorScheme.onPrimaryContainer,
              ),
            ],
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
