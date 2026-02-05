import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../shared/widgets/accessible_card.dart';

/// Settings screen for app preferences
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsRepository = getIt<SettingsRepository>();
  final _userApi = getIt<UserApi>();

  String _userRole = '';
  String _userName = '';
  String _uniqueCode = '';
  String _userTimezone = 'UTC';
  String _themeMode = 'system';
  bool _highContrast = false;
  bool _notificationSound = true;
  bool _hapticFeedback = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      _userRole = await _settingsRepository.getUserRole() ?? 'caregiver';
      _themeMode = await _settingsRepository.getThemeMode();
      _highContrast = await _settingsRepository.isHighContrastEnabled();
      _notificationSound = await _settingsRepository.isNotificationSoundEnabled();
      _hapticFeedback = await _settingsRepository.isHapticFeedbackEnabled();

      final userId = await _settingsRepository.getCurrentUserId();
      if (userId != null) {
        final user = await getIt<UserRepository>().getUserById(userId);
        _userName = user?.name ?? '';
        _uniqueCode = user?.uniqueCode ?? '';

        // Fetch timezone from API
        try {
          final userData = await _userApi.getCurrentUser();
          _userTimezone = userData.timezone;
        } catch (e) {
          debugPrint('Error fetching user timezone: $e');
        }
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_userRole == 'caregiver') {
              context.go(AppRoutes.caregiverHome);
            } else {
              context.go(AppRoutes.dependentHome);
            }
          },
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          // Profile section
          _buildSectionHeader('Profile'),
          AccessibleCard(
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    _userName.isEmpty ? 'User' : _userName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _userRole == 'caregiver' ? 'Caregiver' : 'Dependent',
                  ),
                ),
                if (_uniqueCode.isNotEmpty) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Unique Code',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.qr_code,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: SelectableText(
                                  _uniqueCode,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: _uniqueCode),
                                  );
                                  HapticFeedback.lightImpact();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Code copied to clipboard'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                tooltip: 'Copy code',
                              ),
                              IconButton(
                                icon: const Icon(Icons.share),
                                onPressed: () {
                                  Share.share(
                                    'My Parental Care code is: $_uniqueCode\n\nUse this code to connect with me in the app.',
                                    subject: 'My Parental Care Code',
                                  );
                                },
                                tooltip: 'Share code',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Share this code with ${_userRole == 'caregiver' ? 'your dependents' : 'your caregiver'} to connect.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Appearance section
          _buildSectionHeader('Appearance'),
          AccessibleCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6),
                  title: const Text('Theme'),
                  subtitle: Text(_getThemeLabel(_themeMode)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showThemeDialog,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.contrast),
                  title: const Text('High Contrast'),
                  subtitle: const Text('Increases text visibility'),
                  value: _highContrast,
                  onChanged: (value) async {
                    await _settingsRepository.setHighContrast(value);
                    setState(() => _highContrast = value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Notifications section
          _buildSectionHeader('Notifications & Feedback'),
          AccessibleCard(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up),
                  title: const Text('Notification Sound'),
                  subtitle: const Text('Play sound for reminders'),
                  value: _notificationSound,
                  onChanged: (value) async {
                    await _settingsRepository.setNotificationSoundEnabled(value);
                    setState(() => _notificationSound = value);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration),
                  title: const Text('Haptic Feedback'),
                  subtitle: const Text('Vibration on interactions'),
                  value: _hapticFeedback,
                  onChanged: (value) async {
                    await _settingsRepository.setHapticFeedbackEnabled(value);
                    setState(() => _hapticFeedback = value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Timezone section
          _buildSectionHeader('Time & Location'),
          AccessibleCard(
            child: ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Timezone'),
              subtitle: Text(_userTimezone),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await context.push(AppRoutes.timezoneSettings);
                // Reload settings when returning from timezone screen
                _loadSettings();
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // About section
          _buildSectionHeader('About'),
          AccessibleCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Version'),
                  subtitle: Text(AppConfig.appVersion),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming soon')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help & Support'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming soon')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Danger zone
          _buildSectionHeader('Account'),
          AccessibleCard(
            borderColor: colorScheme.error,
            borderWidth: 1,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.swap_horiz, color: colorScheme.primary),
                  title: const Text('Switch Role'),
                  subtitle: Text(
                    'Currently: ${_userRole == 'caregiver' ? 'Caregiver' : 'Dependent'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showSwitchRoleDialog,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout, color: colorScheme.error),
                  title: Text(
                    'Reset App',
                    style: TextStyle(color: colorScheme.error),
                  ),
                  subtitle: const Text('Clear all data and start over'),
                  onTap: _showResetDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
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

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption('system', 'System default', Icons.settings_suggest),
            _buildThemeOption('light', 'Light', Icons.light_mode),
            _buildThemeOption('dark', 'Dark', Icons.dark_mode),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(String value, String label, IconData icon) {
    final isSelected = _themeMode == value;

    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
      onTap: () async {
        await _settingsRepository.setThemeMode(value);
        setState(() => _themeMode = value);
        if (mounted) Navigator.pop(context);
      },
    );
  }

  void _showSwitchRoleDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final newRole = _userRole == 'caregiver' ? 'dependent' : 'caregiver';
    final newRoleLabel = newRole == 'caregiver' ? 'Caregiver' : 'Dependent';
    final currentRoleLabel = _userRole == 'caregiver' ? 'Caregiver' : 'Dependent';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 28),
            const SizedBox(width: 8),
            const Text('Change Role?'),
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
                      'This will completely change your app experience!',
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
              'You are about to switch from:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildRoleBadge(currentRoleLabel, colorScheme.primary, theme),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                _buildRoleBadge(newRoleLabel, colorScheme.secondary, theme),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              newRole == 'dependent'
                  ? '• You will see the simplified Dependent interface\n• Your caregiver dashboard will be hidden\n• You can switch back anytime'
                  : '• You will see the full Caregiver interface\n• You can manage dependents and reminders\n• You can switch back anytime',
              style: theme.textTheme.bodySmall?.copyWith(
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
              await _settingsRepository.setUserRole(newRole);
              if (mounted) {
                Navigator.pop(dialogContext);
                if (newRole == 'caregiver') {
                  context.go(AppRoutes.caregiverHome);
                } else {
                  context.go(AppRoutes.dependentHome);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
            ),
            child: Text('Switch to $newRoleLabel'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String label, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset App'),
        content: const Text(
          'This will delete all your data including reminders, contacts, and settings. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _settingsRepository.clearAllSettings();
              if (mounted) {
                Navigator.pop(context);
                context.go(AppRoutes.welcome);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
