import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../data/datasources/local/database.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../shared/widgets/widgets.dart';

/// Screen for selecting a dependent to manage
class DependentSelectorScreen extends StatefulWidget {
  const DependentSelectorScreen({super.key});

  @override
  State<DependentSelectorScreen> createState() => _DependentSelectorScreenState();
}

class _DependentSelectorScreenState extends State<DependentSelectorScreen> {
  final _userRepository = getIt<UserRepository>();
  final _settingsRepository = getIt<SettingsRepository>();

  List<User> _dependents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDependents();
  }

  Future<void> _loadDependents() async {
    setState(() => _isLoading = true);

    try {
      final userId = await _settingsRepository.getCurrentUserId();
      if (userId != null) {
        _dependents = await _userRepository.getDependentsForCaregiver(userId);
      }
    } catch (e) {
      debugPrint('Error loading dependents: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Dependent'),
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : _dependents.isEmpty
              ? EmptyState(
                  icon: Icons.people_outline,
                  title: 'No Dependents',
                  message: 'Add a dependent from the home screen first.',
                  actionLabel: 'Go Back',
                  onAction: () => context.go(AppRoutes.caregiverHome),
                )
              : ListView.builder(
                  padding: AppSpacing.screenPadding,
                  itemCount: _dependents.length,
                  itemBuilder: (context, index) {
                    final dependent = _dependents[index];
                    return _DependentTile(
                      dependent: dependent,
                      onTap: () => context.goToDependentDashboard(dependent.id),
                    );
                  },
                ),
    );
  }
}

class _DependentTile extends StatelessWidget {
  final User dependent;
  final VoidCallback onTap;

  const _DependentTile({
    required this.dependent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AccessibleCard(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            radius: 28,
            child: Text(
              dependent.name.isNotEmpty ? dependent.name[0].toUpperCase() : '?',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dependent.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Tap to manage reminders',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: colorScheme.onSurfaceVariant,
            size: 28,
          ),
        ],
      ),
    );
  }
}
