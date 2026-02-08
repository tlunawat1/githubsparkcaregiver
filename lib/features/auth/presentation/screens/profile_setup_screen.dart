import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../shared/widgets/accessible_button.dart';

/// Screen for setting up user profile after role selection
class ProfileSetupScreen extends StatefulWidget {
  final String role;

  const ProfileSetupScreen({
    super.key,
    required this.role,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _completeSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userRepository = getIt<UserRepository>();
      final settingsRepository = getIt<SettingsRepository>();

      final userId = const Uuid().v4();
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();

      // Create user
      await userRepository.createUser(
        id: userId,
        firstName: firstName,
        lastName: lastName.isEmpty ? null : lastName,
        role: widget.role,
      );

      // Save settings
      await settingsRepository.setCurrentUserId(userId);
      await settingsRepository.setUserRole(widget.role);
      await settingsRepository.setOnboardingComplete(true);

      // For dependent role, also create a "self" relationship for local testing
      if (widget.role == 'dependent') {
        // Dependent is set, ready to receive reminders
        await settingsRepository.setSelectedDependentId(userId);
      }

      if (mounted) {
        // Navigate to the appropriate home screen
        if (widget.role == 'caregiver') {
          context.go(AppRoutes.caregiverHome);
        } else {
          context.go(AppRoutes.dependentHome);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error setting up profile: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCaregiver = widget.role == 'caregiver';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Up Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.roleSelection),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),
                // Role badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isCaregiver
                        ? colorScheme.primaryContainer
                        : colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCaregiver ? Icons.favorite : Icons.person,
                        size: 16,
                        color: isCaregiver
                            ? colorScheme.primary
                            : colorScheme.secondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isCaregiver ? 'Caregiver' : 'Dependent',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isCaregiver
                              ? colorScheme.primary
                              : colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'What\'s your name?',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  isCaregiver
                      ? 'This will help your dependents identify who set up their reminders.'
                      : 'This will help your caregivers identify you.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                // First name input
                TextFormField(
                  controller: _firstNameController,
                  decoration: InputDecoration(
                    labelText: 'First Name *',
                    hintText: 'Enter your first name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  style: theme.textTheme.bodyLarge,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your first name';
                    }
                    if (value.trim().length < 2) {
                      return 'First name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                // Last name input (optional)
                TextFormField(
                  controller: _lastNameController,
                  decoration: InputDecoration(
                    labelText: 'Last Name',
                    hintText: 'Enter your last name (optional)',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  style: theme.textTheme.bodyLarge,
                  onFieldSubmitted: (_) => _completeSetup(),
                ),
                const SizedBox(height: AppSpacing.xxl),
                // Additional info for caregiver
                if (isCaregiver) ...[
                  _InfoCard(
                    icon: Icons.info_outline,
                    title: 'Next Steps',
                    description:
                        'After setup, you\'ll be able to add dependents and create reminders for them.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                // Additional info for dependent
                if (!isCaregiver) ...[
                  _InfoCard(
                    icon: Icons.info_outline,
                    title: 'Getting Started',
                    description:
                        'After setup, you\'ll see your reminders on the home screen and can use the SOS button if needed.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                const SizedBox(height: AppSpacing.xl),
                // Complete button
                AccessibleButton(
                  onPressed: _isLoading ? null : _completeSetup,
                  label: 'Complete Setup',
                  icon: Icons.check,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
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
      ),
    );
  }
}
