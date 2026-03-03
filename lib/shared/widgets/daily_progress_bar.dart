import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';

/// A progress bar showing daily reminder completion status.
class DailyProgressBar extends StatelessWidget {
  const DailyProgressBar({
    super.key,
    required this.completed,
    required this.total,
    this.showLabel = true,
    this.height = 12.0,
  });

  final int completed;
  final int total;
  final bool showLabel;
  final double height;

  double get progress => total > 0 ? completed / total : 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Today\'s Progress',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '$completed of $total done',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        Stack(
          children: [
            // Background track
            Container(
              height: height,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
            // Progress fill
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              height: height,
              width: double.infinity,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.success,
                        AppColors.successDark,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(height / 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (total > 0 && showLabel)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              _getProgressMessage(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: _getProgressColor(),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  String _getProgressMessage() {
    if (total == 0) return 'No reminders today';
    if (completed == total) return 'All done! Great job!';
    if (progress >= 0.75) return 'Almost there!';
    if (progress >= 0.5) return 'Halfway done';
    if (progress > 0) return 'Keep going!';
    return 'Let\'s get started';
  }

  Color _getProgressColor() {
    if (completed == total) return AppColors.success;
    if (progress >= 0.5) return AppColors.primary;
    return AppColors.warning;
  }
}

/// A circular progress indicator for showing completion.
class CircularProgressBadge extends StatelessWidget {
  const CircularProgressBadge({
    super.key,
    required this.completed,
    required this.total,
    this.size = 80,
  });

  final int completed;
  final int total;
  final double size;

  double get progress => total > 0 ? completed / total : 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 8,
              valueColor: AlwaysStoppedAnimation(
                Colors.grey.withValues(alpha: 0.2),
              ),
            ),
          ),
          // Progress circle
          SizedBox(
            width: size,
            height: size,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return CircularProgressIndicator(
                  value: value,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  valueColor: AlwaysStoppedAnimation(
                    value >= 1.0 ? AppColors.success : AppColors.primary,
                  ),
                );
              },
            ),
          ),
          // Center text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$completed/$total',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'done',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
