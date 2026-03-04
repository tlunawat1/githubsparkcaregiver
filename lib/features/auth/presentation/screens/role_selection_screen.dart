import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/redesign_tokens.dart';
import '../../../../shared/widgets/redesign_ui.dart';

/// Read-only onboarding info screen that explains the two roles.
///
/// Replaces the old [RoleSelectionScreen]. Role selection now happens
/// only during registration.
class OnboardingInfoScreen extends StatelessWidget {
  const OnboardingInfoScreen({super.key});

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
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - (AppSpacing.md * 2),
                      maxWidth: 430,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            IconButton.filledTonal(
                              onPressed: () => context.go(AppRoutes.welcome),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'How We Care',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Built with care and protected with trust.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // --- Companion info card ---
                        _InfoCard(
                          icon: Icons.favorite,
                          title: 'Companion',
                          description:
                              'Be there for your loved ones. Create reminders, follow up and organize care for your Loved One.',
                          chipLabels: const [
                            'Stay Connected',
                            'Create Reminders',
                            'Track Progress',
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // --- Loved One info card ---
                        _InfoCard(
                          icon: Icons.star,
                          title: 'Loved One',
                          description:
                              'Stay on top of your schedule, feel connected and cared for with gentle reminders.',
                          chipLabels: const [
                            'Feel Loved',
                            'Gentle Reminders',
                            'Emergency SOS',
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // --- CTA ---
                        GradientPrimaryButton(
                          onPressed: () => context.go(AppRoutes.login),
                          label: "Let's Get Started",
                          icon: Icons.arrow_forward_rounded,
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

/// A read-only glass card describing a role.
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<String> chipLabels;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.chipLabels,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconColor = RedesignTokens.primary;

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46.r,
                height: 46.r,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(icon, color: iconColor, size: 26.r),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: chipLabels.map((label) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
