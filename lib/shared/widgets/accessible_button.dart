import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_spacing.dart';

/// A large, accessible button designed for elderly users.
/// Features 64dp minimum touch target, haptic feedback, and clear visual states.
class AccessibleButton extends StatelessWidget {
  const AccessibleButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.isLoading = false,
    this.isDestructive = false,
    this.size = AccessibleButtonSize.large,
    this.fullWidth = true,
    this.enableHapticFeedback = true,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isLoading;
  final bool isDestructive;
  final AccessibleButtonSize size;
  final bool fullWidth;
  final bool enableHapticFeedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bgColor = backgroundColor ??
        (isDestructive ? colorScheme.error : colorScheme.primary);
    final fgColor = foregroundColor ??
        (isDestructive ? colorScheme.onError : colorScheme.onPrimary);

    final buttonHeight = switch (size) {
      AccessibleButtonSize.small => AppTouchTargets.minimum,
      AccessibleButtonSize.medium => 56.0,
      AccessibleButtonSize.large => AppTouchTargets.elderly,
      AccessibleButtonSize.xlarge => AppTouchTargets.large,
    };

    final fontSize = switch (size) {
      AccessibleButtonSize.small => 16.0,
      AccessibleButtonSize.medium => 18.0,
      AccessibleButtonSize.large => 20.0,
      AccessibleButtonSize.xlarge => 24.0,
    };

    final iconSize = switch (size) {
      AccessibleButtonSize.small => 20.0,
      AccessibleButtonSize.medium => 24.0,
      AccessibleButtonSize.large => 28.0,
      AccessibleButtonSize.xlarge => 32.0,
    };

    Widget buttonChild = isLoading
        ? SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          )
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: iconSize),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () {
                if (enableHapticFeedback) {
                  HapticFeedback.mediumImpact();
                }
                onPressed?.call();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          disabledBackgroundColor: bgColor.withValues(alpha: 0.5),
          disabledForegroundColor: fgColor.withValues(alpha: 0.7),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.largeRadius,
          ),
          elevation: 2,
        ),
        child: buttonChild,
      ),
    );
  }
}

/// Accessible outlined button variant
class AccessibleOutlinedButton extends StatelessWidget {
  const AccessibleOutlinedButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.borderColor,
    this.foregroundColor,
    this.isLoading = false,
    this.size = AccessibleButtonSize.large,
    this.fullWidth = true,
    this.enableHapticFeedback = true,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final Color? borderColor;
  final Color? foregroundColor;
  final bool isLoading;
  final AccessibleButtonSize size;
  final bool fullWidth;
  final bool enableHapticFeedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final color = foregroundColor ?? colorScheme.primary;
    final border = borderColor ?? colorScheme.primary;

    final buttonHeight = switch (size) {
      AccessibleButtonSize.small => AppTouchTargets.minimum,
      AccessibleButtonSize.medium => 56.0,
      AccessibleButtonSize.large => AppTouchTargets.elderly,
      AccessibleButtonSize.xlarge => AppTouchTargets.large,
    };

    final fontSize = switch (size) {
      AccessibleButtonSize.small => 16.0,
      AccessibleButtonSize.medium => 18.0,
      AccessibleButtonSize.large => 20.0,
      AccessibleButtonSize.xlarge => 24.0,
    };

    final iconSize = switch (size) {
      AccessibleButtonSize.small => 20.0,
      AccessibleButtonSize.medium => 24.0,
      AccessibleButtonSize.large => 28.0,
      AccessibleButtonSize.xlarge => 32.0,
    };

    Widget buttonChild = isLoading
        ? SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          )
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: iconSize),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: buttonHeight,
      child: OutlinedButton(
        onPressed: isLoading
            ? null
            : () {
                if (enableHapticFeedback) {
                  HapticFeedback.mediumImpact();
                }
                onPressed?.call();
              },
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.largeRadius,
          ),
          side: BorderSide(color: border, width: 2),
        ),
        child: buttonChild,
      ),
    );
  }
}

enum AccessibleButtonSize {
  small,
  medium,
  large,
  xlarge,
}
