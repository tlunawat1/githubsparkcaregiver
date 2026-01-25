import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../shared/models/user_role.dart';

/// Screen for selecting user role (Caregiver or Dependent)
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Who are you?'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.welcome),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Select your role',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This determines how you\'ll use the app. You can switch roles later in settings.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Caregiver option
              _RoleCard(
                role: UserRole.caregiver,
                icon: Icons.favorite,
                title: 'I\'m a Caregiver',
                description: 'Set reminders, manage contacts, and monitor your loved ones',
                features: const [
                  'Create and manage reminders',
                  'Add voice notes to reminders',
                  'Set up emergency contacts',
                  'View activity status',
                ],
                onTap: () => _selectRole(context, UserRole.caregiver),
              ),
              const SizedBox(height: AppSpacing.md),
              // Dependent option
              _RoleCard(
                role: UserRole.dependent,
                icon: Icons.person,
                title: 'I\'m a Dependent',
                description: 'Receive reminders and get help when you need it',
                features: const [
                  'Receive gentle reminders',
                  'Listen to voice messages',
                  'One-tap SOS emergency button',
                  'Simple, easy-to-use interface',
                ],
                onTap: () => _selectRole(context, UserRole.dependent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectRole(BuildContext context, UserRole role) {
    HapticFeedback.mediumImpact();
    context.go('${AppRoutes.login}?role=${role.name}');
  }
}

class _RoleCard extends StatelessWidget {
  final UserRole role;
  final IconData icon;
  final String title;
  final String description;
  final List<String> features;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.icon,
    required this.title,
    required this.description,
    required this.features,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isPrimary = role == UserRole.caregiver;
    final cardColor = isPrimary
        ? colorScheme.primaryContainer
        : colorScheme.secondaryContainer;
    final iconColor = isPrimary
        ? colorScheme.primary
        : colorScheme.secondary;

    return Semantics(
      label: '$title. $description',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: iconColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: iconColor,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: features.map((feature) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: iconColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          feature,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
