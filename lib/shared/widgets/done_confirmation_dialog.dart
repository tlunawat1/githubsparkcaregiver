import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/haptics.dart';

/// A custom confirmation dialog that asks the user to confirm
/// before marking a reminder as done.
///
/// Returns `true` if the user confirms, `false` or `null` if dismissed.
class DoneConfirmationDialog extends StatelessWidget {
  const DoneConfirmationDialog({
    super.key,
    required this.reminderTitle,
  });

  final String reminderTitle;

  /// Shows the confirmation dialog and returns `true` if user confirms.
  static Future<bool> show(BuildContext context, {required String reminderTitle}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => DoneConfirmationDialog(reminderTitle: reminderTitle),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.xlargeRadius,
      ),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Check icon in a circle
            Container(
              width: 72.r,
              height: 72.r,
              decoration: BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                  width: 3,
                ),
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 40.r,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Title
            Text(
              'Mark as Done?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),

            // Reminder name
            Text(
              'Have you completed "$reminderTitle"?',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Confirm button
            SizedBox(
              width: double.infinity,
              height: AppTouchTargets.elderly,
              child: ElevatedButton.icon(
                onPressed: () {
                  Haptics.mediumImpact();
                  Navigator.pop(context, true);
                },
                icon: const Icon(Icons.check, size: 24),
                label: const Text(
                  'Yes, Done!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.largeRadius,
                  ),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Cancel button
            SizedBox(
              width: double.infinity,
              height: AppTouchTargets.elderly,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context, false);
                },
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.largeRadius,
                  ),
                ),
                child: const Text(
                  'Not Yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
