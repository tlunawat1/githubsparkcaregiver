import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/custom_icons.dart';
import '../../core/utils/category_inference.dart';
import '../../core/utils/haptics.dart';

/// Data model for a timeline item
class TimelineItem {
  final String id;
  final String title;
  final DateTime scheduledTime;
  final String status; // 'pending', 'completed', 'missed', 'snoozed'
  final bool hasVoiceNote;
  final String? description;

  const TimelineItem({
    required this.id,
    required this.title,
    required this.scheduledTime,
    required this.status,
    this.hasVoiceNote = false,
    this.description,
  });
}

/// A vertical timeline view showing reminders chronologically.
class TimelineView extends StatelessWidget {
  const TimelineView({
    super.key,
    required this.items,
    this.onItemTap,
    this.emptyMessage = 'No reminders scheduled',
    this.sortByTimeAscending = true,
    this.disableSorting = false,
  });

  final List<TimelineItem> items;
  final void Function(TimelineItem item)? onItemTap;
  final String emptyMessage;
  final bool sortByTimeAscending;
  final bool disableSorting;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyTimelineMessage(message: emptyMessage);
    }

    final sortedItems = disableSorting
        ? items
        : (List<TimelineItem>.from(items)
          ..sort((a, b) => sortByTimeAscending
              ? a.scheduledTime.compareTo(b.scheduledTime)
              : b.scheduledTime.compareTo(a.scheduledTime)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < sortedItems.length; i++)
          _TimelineItemWidget(
            item: sortedItems[i],
            isFirst: i == 0,
            isLast: i == sortedItems.length - 1,
            onTap: onItemTap != null ? () => onItemTap!(sortedItems[i]) : null,
          ),
      ],
    );
  }
}

class _TimelineItemWidget extends StatelessWidget {
  const _TimelineItemWidget({
    required this.item,
    required this.isFirst,
    required this.isLast,
    this.onTap,
  });

  final TimelineItem item;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;

  Color _getStatusColor() {
    return switch (item.status) {
      'completed' => AppColors.success,
      'missed' => AppColors.error,
      'snoozed' => AppColors.info,
      _ => AppColors.warning,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _getStatusColor();
    final category = CategoryInference.inferCategory(item.title);
    final categoryColor = AppIcons.getCategoryColor(category);
    final timeFormat = DateFormat.jm();

    return InkWell(
      onTap: onTap != null
          ? () {
              Haptics.selectionClick();
              onTap!();
            }
          : null,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark
              ? statusColor.withValues(alpha: 0.1)
              : statusColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                AppIcons.getCategoryIcon(category),
                color: categoryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Title and time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: item.status == 'completed'
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeFormat.format(item.scheduledTime),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.status[0].toUpperCase() + item.status.substring(1),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Voice note indicator
            if (item.hasVoiceNote) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(
                AppIcons.voiceNote,
                size: 16,
                color: colorScheme.primary,
              ),
            ],
            // Arrow for tappable items
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(
                AppIcons.forward,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyTimelineMessage extends StatelessWidget {
  const _EmptyTimelineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_available_rounded,
              color: AppColors.success,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All Caught Up!',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
