import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../shared/widgets/accessible_button.dart';

/// Welcome screen shown on first app launch
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            children: [
              const Spacer(flex: 2),
              // App icon/logo placeholder
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite,
                  size: 64,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Title
              Text(
                'Parental Care',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              // Subtitle
              Text(
                'Stay connected with your loved ones',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              // Features list
              _FeatureItem(
                icon: Icons.notifications_active,
                title: 'Gentle Reminders',
                description: 'Set reminders for medications, appointments, and daily tasks',
              ),
              const SizedBox(height: AppSpacing.md),
              _FeatureItem(
                icon: Icons.sos,
                title: 'Emergency SOS',
                description: 'Quick access to help when it\'s needed most',
              ),
              const SizedBox(height: AppSpacing.md),
              _FeatureItem(
                icon: Icons.mic,
                title: 'Voice Messages',
                description: 'Add personal voice notes to reminders',
              ),
              const Spacer(flex: 3),
              // Get started button
              AccessibleButton(
                onPressed: () => context.go(AppRoutes.roleSelection),
                label: 'Get Started',
                icon: Icons.arrow_forward,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
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

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: colorScheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
