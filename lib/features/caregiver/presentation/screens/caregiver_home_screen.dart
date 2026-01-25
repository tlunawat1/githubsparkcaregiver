import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../data/datasources/local/database.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../shared/widgets/widgets.dart';

/// Main home screen for caregivers showing their dependents
class CaregiverHomeScreen extends StatefulWidget {
  const CaregiverHomeScreen({super.key});

  @override
  State<CaregiverHomeScreen> createState() => _CaregiverHomeScreenState();
}

class _CaregiverHomeScreenState extends State<CaregiverHomeScreen> {
  final _userRepository = getIt<UserRepository>();
  final _settingsRepository = getIt<SettingsRepository>();

  User? _currentUser;
  List<User> _dependents = [];
  bool _isLoading = true;
  String _themeMode = 'system';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final userId = await _settingsRepository.getCurrentUserId();
      _themeMode = await _settingsRepository.getThemeMode();
      if (userId != null) {
        _currentUser = await _userRepository.getUserById(userId);
        _dependents = await _userRepository.getDependentsForCaregiver(userId);
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hello, ${_currentUser?.name ?? 'Caregiver'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, size: 28),
            onPressed: () => _showSettingsBottomSheet(context),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator(message: 'Loading...')
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _dependents.isEmpty
                  ? _buildEmptyState()
                  : _buildDependentsList(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDependentDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Dependent'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.people_outline,
      title: 'No Dependents Yet',
      message: 'Add a dependent to start creating reminders and stay connected.',
      actionLabel: 'Add Dependent',
      onAction: _showAddDependentDialog,
    );
  }

  Widget _buildDependentsList() {
    return ListView.builder(
      padding: AppSpacing.screenPadding,
      itemCount: _dependents.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'Your Dependents',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        final dependent = _dependents[index - 1];
        return _DependentCard(
          dependent: dependent,
          onTap: () => context.goToDependentDashboard(dependent.id),
        );
      },
    );
  }

  void _showAddDependentDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Dependent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the name of the person you\'ll be caring for.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter dependent\'s name',
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              Navigator.pop(context);
              await _addDependent(name);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addDependent(String name) async {
    try {
      final userRepository = getIt<UserRepository>();
      final careRelationshipRepository = getIt<CareRelationshipRepository>();

      // Create dependent user
      final dependentId = DateTime.now().millisecondsSinceEpoch.toString();
      await userRepository.createUser(
        id: dependentId,
        name: name,
        role: 'dependent',
      );

      // Create care relationship
      final relationshipId = '${_currentUser!.id}_$dependentId';
      await careRelationshipRepository.createRelationship(
        id: relationshipId,
        caregiverId: _currentUser!.id,
        dependentId: dependentId,
      );

      // Reload data
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name has been added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding dependent: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showSettingsBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Settings',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(
                  _themeMode == 'dark' ? Icons.dark_mode : Icons.light_mode,
                  color: colorScheme.primary,
                ),
                title: const Text('Theme'),
                subtitle: Text(_getThemeLabel(_themeMode)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  _showThemeDialog(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.swap_horiz, color: colorScheme.secondary),
                title: const Text('Switch to Dependent'),
                subtitle: const Text('Change app mode'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  _showSwitchRoleDialog(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.logout, color: colorScheme.error),
                title: Text('Reset App', style: TextStyle(color: colorScheme.error)),
                subtitle: const Text('Clear all data'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  _showResetDialog(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.settings, color: colorScheme.onSurfaceVariant),
                title: const Text('All Settings'),
                subtitle: const Text('View more options'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  context.go(AppRoutes.settings);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getThemeLabel(String mode) {
    switch (mode) {
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      default:
        return 'System default';
    }
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(dialogContext, 'system', 'System default', Icons.settings_suggest),
            _buildThemeOption(dialogContext, 'light', 'Light', Icons.light_mode),
            _buildThemeOption(dialogContext, 'dark', 'Dark', Icons.dark_mode),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(BuildContext dialogContext, String value, String label, IconData icon) {
    final isSelected = _themeMode == value;

    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
      onTap: () async {
        await _settingsRepository.setThemeMode(value);
        setState(() => _themeMode = value);
        if (mounted) Navigator.pop(dialogContext);
      },
    );
  }

  void _showSwitchRoleDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 28),
            const SizedBox(width: 8),
            const Text('Switch to Dependent?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will change your app experience!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '• You will see the Dependent interface\n• Your caregiver dashboard will be hidden\n• You can switch back anytime',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _settingsRepository.setUserRole('dependent');
              Navigator.pop(dialogContext);
              if (mounted) {
                // Use the widget's context for navigation after dialog is closed
                GoRouter.of(this.context).go(AppRoutes.dependentHome);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
            ),
            child: const Text('Switch to Dependent'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset App'),
        content: const Text(
          'This will delete all your data including reminders, contacts, and settings. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _settingsRepository.clearAllSettings();
              if (mounted) {
                Navigator.pop(dialogContext);
                context.go(AppRoutes.welcome);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _DependentCard extends StatelessWidget {
  final User dependent;
  final VoidCallback onTap;

  const _DependentCard({
    required this.dependent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // For MVP, status is always "good" since we're not tracking real activity
    const status = CardStatus.good;

    return StatusCard(
      title: dependent.name,
      subtitle: 'Tap to view reminders',
      status: status,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        radius: 24,
        child: Text(
          dependent.name.isNotEmpty ? dependent.name[0].toUpperCase() : '?',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
