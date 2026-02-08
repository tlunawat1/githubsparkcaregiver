import 'package:flutter/material.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/haptics.dart';

/// An accessible card widget with large touch targets and clear visual feedback.
class AccessibleCard extends StatelessWidget {
  const AccessibleCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0,
    this.elevation = 2,
    this.enableHapticFeedback = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double elevation;
  final bool enableHapticFeedback;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final cardContent = Container(
      padding: padding ?? AppSpacing.cardPadding,
      child: child,
    );

    final card = Card(
      margin: margin ?? const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      elevation: onTap != null ? elevation : elevation / 2,
      color: backgroundColor ?? colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.largeRadius,
        side: borderWidth > 0
            ? BorderSide(
                color: borderColor ?? colorScheme.outline,
                width: borderWidth,
              )
            : BorderSide.none,
      ),
      child: onTap != null || onLongPress != null
          ? InkWell(
              onTap: () {
                if (enableHapticFeedback) {
                  Haptics.selectionClick();
                }
                onTap?.call();
              },
              onLongPress: onLongPress != null
                  ? () {
                      if (enableHapticFeedback) {
                        Haptics.mediumImpact();
                      }
                      onLongPress?.call();
                    }
                  : null,
              borderRadius: AppRadius.largeRadius,
              child: cardContent,
            )
          : cardContent,
    );

    if (semanticLabel != null) {
      return Semantics(
        label: semanticLabel,
        button: onTap != null,
        child: card,
      );
    }

    return card;
  }
}

/// A status card with colored indicator for dependent status display
class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.status,
    this.onTap,
    this.trailing,
    this.leading,
  });

  final String title;
  final String subtitle;
  final CardStatus status;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final statusColor = switch (status) {
      CardStatus.good => Colors.green,
      CardStatus.warning => Colors.orange,
      CardStatus.urgent => Colors.red,
      CardStatus.neutral => colorScheme.outline,
    };

    return AccessibleCard(
      onTap: onTap,
      borderColor: statusColor,
      borderWidth: 2,
      semanticLabel: '$title, $subtitle, status: ${status.name}',
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 12,
            height: 60,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Leading widget
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.md),
          ],
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Trailing widget
          if (trailing != null) trailing!,
          if (onTap != null)
            Icon(
              Icons.chevron_right,
              size: 28,
              color: colorScheme.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}

enum CardStatus {
  good,
  warning,
  urgent,
  neutral,
}
