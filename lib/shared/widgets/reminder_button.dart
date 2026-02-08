import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/custom_icons.dart';
import '../../core/utils/category_inference.dart';
import '../../core/utils/haptics.dart';

/// Status of a reminder instance
enum ReminderInstanceStatus {
  pending,
  completed,
  missed,
  snoozed,
}

/// A square-ish button widget for displaying reminder instances.
/// Features one-tap completion, color-coded status, category icons, and a details button.
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
    final category = CategoryInference.inferCategory(title);
    final categoryColor = AppIcons.getCategoryColor(category);
    final categoryIcon = AppIcons.getCategoryIcon(category);

    final (backgroundColor, borderColor, textColor) = switch (status) {
      ReminderInstanceStatus.pending => (
          AppColors.warningLight,
          AppColors.warning,
          AppColors.warningDark,
        ),
      ReminderInstanceStatus.completed => (
          AppColors.successLight,
          AppColors.success,
          AppColors.successDark,
        ),
      ReminderInstanceStatus.missed => (
          AppColors.errorLight,
          AppColors.error,
          AppColors.errorDark,
        ),
      ReminderInstanceStatus.snoozed => (
          AppColors.infoLight,
          AppColors.info,
          AppColors.infoDark,
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
                      Haptics.mediumImpact();
                      onTap?.call();
                    }
                  : null,
          borderRadius: AppRadius.largeRadius,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.largeRadius,
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row with category icon and details button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        categoryIcon,
                        color: categoryColor,
                        size: 22,
                      ),
                    ),
                    GestureDetector(
                      onTap: isLoading
                          ? null
                          : () {
                              Haptics.lightImpact();
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
                  ],
                ),
                const SizedBox(height: 4),
                // Title
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    decoration: status == ReminderInstanceStatus.completed
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Time + status row
                if (isLoading)
                  SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        time,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: borderColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      _buildStatusChip(theme, textColor, borderColor),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme, Color textColor, Color borderColor) {
    final (icon, label) = switch (status) {
      ReminderInstanceStatus.pending => (Icons.touch_app, 'Tap to\ncomplete'),
      ReminderInstanceStatus.completed => (Icons.check_circle, 'Done'),
      ReminderInstanceStatus.missed => (Icons.error, 'Missed'),
      ReminderInstanceStatus.snoozed => (Icons.snooze, 'Snoozed'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: borderColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 10,
              height: 1.1,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
