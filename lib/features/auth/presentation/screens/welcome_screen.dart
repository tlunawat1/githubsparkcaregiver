import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../shared/widgets/redesign_ui.dart';

/// Welcome screen shown on first app launch
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: RedesignBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 430,
                      minHeight: constraints.maxHeight - (AppSpacing.md * 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.16,
                                ),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.25,
                                  ),
                                ),
                              ),
                              child: Icon(
                                Icons.family_restroom,
                                size: 46,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Parental Care',
                              style: theme.textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              'Stay connected with your loved ones',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const GlassCard(
                          margin: EdgeInsets.zero,
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            children: [
                              _FeatureItem(
                                icon: Icons.notifications_active,
                                title: 'Gentle Reminders',
                                description:
                                    'Set reminders for medications, appointments, and daily tasks.',
                              ),
                              SizedBox(height: AppSpacing.sm),
                              _FeatureItem(
                                icon: Icons.emergency,
                                title: 'Emergency SOS',
                                description:
                                    'Quick access to help when it\'s needed most with a single tap.',
                                iconColor: Color(0xFFE06B74),
                              ),
                              SizedBox(height: AppSpacing.sm),
                              _FeatureItem(
                                icon: Icons.mic,
                                title: 'Voice Messages',
                                description:
                                    'Add personal voice notes to reminders for a human touch.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        GradientPrimaryButton(
                          onPressed: () => context.go(AppRoutes.roleSelection),
                          label: 'Get Started',
                          icon: Icons.arrow_forward_rounded,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Trusted by 50,000+ families',
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.3,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.9,
                            ),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(
                          height: MediaQuery.paddingOf(context).bottom > 0
                              ? 0
                              : AppSpacing.sm,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color? iconColor;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tone = iconColor ?? colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: tone, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
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
