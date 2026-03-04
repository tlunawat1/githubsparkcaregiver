import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/services/fcm_service.dart';
import '../../../../core/services/notification_handler.dart';
import '../../../../core/services/reminder_alarm_service.dart';
import '../../../../core/utils/feedback_settings.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../shared/widgets/accessible_card.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/redesign_ui.dart';
import '../../../../shared/widgets/swipe_to_logout_button.dart';
import 'linked_user_detail_screen.dart';

/// Settings screen for app preferences
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsRepository = getIt<SettingsRepository>();
  final _userApi = getIt<UserApi>();
  final _authApi = getIt<AuthApi>();
  final _relationshipApi = getIt<RelationshipApi>();

  String _userRole = '';
  String _userName = '';
  String _userEmail = '';
  String? _userPhone;
  String _uniqueCode = '';
  String _userTimezone = 'UTC';
  String _themeMode = 'system';
  bool _notificationSound = true;
  bool _hapticFeedback = true;
  bool _isLoading = true;
  List<RelationshipData> _linkedUsers = [];
  bool _isLoadingLinkedUsers = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      _userRole = await _settingsRepository.getUserRole() ?? 'caregiver';
      _themeMode = await _settingsRepository.getThemeMode();
      _notificationSound = await _settingsRepository
          .isNotificationSoundEnabled();
      _hapticFeedback = await _settingsRepository.isHapticFeedbackEnabled();

      // Fetch user data from API
      try {
        final userData = await _userApi.getCurrentUser();
        _userName = userData.name;
        _userEmail = userData.email;
        _userPhone = userData.phoneNumber;
        _uniqueCode = userData.uniqueCode;
        _userTimezone = userData.timezone;
      } catch (e) {
        debugPrint('Error fetching user data: $e');
        // Fallback to local data
        final userId = await _settingsRepository.getCurrentUserId();
        if (userId != null) {
          final user = await getIt<UserRepository>().getUserById(userId);
          _userName = user?.name ?? '';
          _uniqueCode = user?.uniqueCode ?? '';
        }
      }

      // Fetch linked users
      _loadLinkedUsers();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLinkedUsers() async {
    setState(() => _isLoadingLinkedUsers = true);
    try {
      final relationships = await _relationshipApi.getRelationships();
      _linkedUsers = relationships.where((r) => r.isActive).toList();
    } catch (e) {
      debugPrint('Error fetching linked users: $e');
      _linkedUsers = [];
    }
    if (mounted) {
      setState(() => _isLoadingLinkedUsers = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Stop any continuous ringing immediately.
      await ReminderAlarmService.instance.stopAlarm();

      // 1. Invalidate device token on backend & delete FCM token locally.
      //    This must happen BEFORE _authApi.logout() because logout clears
      //    the JWT. cleanupForLogout() also suppresses onTokenRefresh from
      //    re-registering a new token.
      final fcmService = getIt<FcmService>();
      await fcmService.cleanupForLogout();

      // 2. Call API logout (clears refresh token + any remaining device tokens)
      try {
        await _authApi.logout();
      } catch (e) {
        debugPrint('Error during logout: $e');
      }

      // 3. Disconnect SignalR and clear subscriptions
      final signalRService = getIt<SignalRService>();
      await signalRService.disconnect(clearTracking: true);
      debugPrint('SignalR disconnected on logout');

      // 4. Clear local settings
      await _settingsRepository.clearAllSettings();

      if (mounted) {
        context.go(AppRoutes.welcome);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: RedesignBackground(
          child: SafeArea(child: _buildSkeletonLoading()),
        ),
      );
    }

    return Scaffold(
      body: RedesignBackground(
        child: SafeArea(
          child: ListView(
            padding: AppSpacing.screenPadding,
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () {
                      if (_userRole == 'caregiver') {
                        context.go(AppRoutes.caregiverHome);
                      } else {
                        context.go(AppRoutes.dependentHome);
                      }
                    },
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Settings',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Profile section
              _buildSectionHeader('Profile'),
              _buildProfileCard(),
              const SizedBox(height: AppSpacing.lg),

              // My Dependents / My Caregivers section
              _buildSectionHeader(
                _userRole == 'caregiver' ? 'My Loved Ones' : 'My Companions',
              ),
              _buildLinkedUsersSection(),
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
                        await _settingsRepository.setNotificationSoundEnabled(
                          value,
                        );
                        FeedbackSettings.setNotificationSoundEnabled(value);
                        await NotificationHandler()
                            .refreshNotificationChannels();
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
                        await _settingsRepository.setHapticFeedbackEnabled(
                          value,
                        );
                        FeedbackSettings.setHapticFeedbackEnabled(value);
                        await NotificationHandler()
                            .refreshNotificationChannels();
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
              const SizedBox(height: AppSpacing.xl),

              // Logout section
              _buildSectionHeader('Account'),
              SwipeToLogoutButton(onSwipeComplete: _handleLogout),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AccessibleCard(
      child: Column(
        children: [
          // User info with avatar
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  radius: 32.r,
                  child: Text(
                    _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Name and role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName.isEmpty ? 'User' : _userName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.r,
                          vertical: 4.r,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _userRole == 'caregiver' ? 'Companion' : 'Loved One',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Edit profile button
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: colorScheme.primary),
                  onPressed: () async {
                    final updated = await context.push<bool>(
                      AppRoutes.editProfile,
                    );
                    if (updated == true) {
                      _loadSettings(); // Reload to show updated name
                    }
                  },
                  tooltip: 'Edit profile',
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Contact details
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                // Email
                Row(
                  children: [
                    Icon(
                      Icons.email_outlined,
                      color: colorScheme.onSurfaceVariant,
                      size: 20.r,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Email',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            _userEmail.isEmpty ? 'Not set' : _userEmail,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Phone (if available)
                if (_userPhone != null && _userPhone!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        color: colorScheme.onSurfaceVariant,
                        size: 20.r,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Phone',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              _userPhone!,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Unique code section
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
                        Icon(Icons.qr_code, color: colorScheme.primary),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: SelectableText(
                            _uniqueCode,
                            maxLines: 1,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _uniqueCode));
                            Haptics.lightImpact();
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
                    'Share this code with ${_userRole == 'caregiver' ? 'your loved ones' : 'your companion'} to connect.',
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
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView(
      padding: AppSpacing.screenPadding,
      children: const [
        SizedBox(height: 56),
        ShimmerCard(height: 18, width: 140),
        SizedBox(height: AppSpacing.sm),
        ShimmerCard(height: 140),
        SizedBox(height: AppSpacing.lg),
        ShimmerCard(height: 18, width: 180),
        SizedBox(height: AppSpacing.sm),
        ShimmerCard(height: 120),
        SizedBox(height: AppSpacing.lg),
        ShimmerCard(height: 18, width: 150),
        SizedBox(height: AppSpacing.sm),
        ShimmerCard(height: 160),
        SizedBox(height: AppSpacing.lg),
        ShimmerCard(height: 18, width: 200),
        SizedBox(height: AppSpacing.sm),
        ShimmerCard(height: 140),
        SizedBox(height: AppSpacing.lg),
        ShimmerCard(height: 18, width: 160),
        SizedBox(height: AppSpacing.sm),
        ShimmerCard(height: 90),
        SizedBox(height: AppSpacing.lg),
        ShimmerCard(height: 18, width: 120),
        SizedBox(height: AppSpacing.sm),
        ShimmerCard(height: 140),
        SizedBox(height: AppSpacing.xl),
        ShimmerCard(height: 18, width: 120),
        SizedBox(height: AppSpacing.sm),
        ShimmerCard(height: 70),
      ],
    );
  }

  Widget _buildLinkedUsersSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoadingLinkedUsers) {
      return AccessibleCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Center(
            child: CircularProgressIndicator(color: colorScheme.primary),
          ),
        ),
      );
    }

    if (_linkedUsers.isEmpty) {
      final isCaregiver = _userRole == 'caregiver';
      return AccessibleCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Icon(
                isCaregiver ? Icons.people_outline : Icons.person_outline,
                size: 48.r,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                isCaregiver
                    ? 'No loved ones linked yet'
                    : 'No companions linked yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Share your unique code to connect',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return AccessibleCard(
      child: Column(
        children: _linkedUsers.asMap().entries.map((entry) {
          final index = entry.key;
          final relationship = entry.value;
          final linkedUser = _userRole == 'caregiver'
              ? relationship.dependent
              : relationship.caregiver;

          if (linkedUser == null) return const SizedBox.shrink();

          return Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    linkedUser.name.isNotEmpty
                        ? linkedUser.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  linkedUser.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  linkedUser.email ?? linkedUser.uniqueCode,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    _navigateToLinkedUserDetail(relationship, linkedUser),
              ),
              if (index < _linkedUsers.length - 1) const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  Future<void> _navigateToLinkedUserDetail(
    RelationshipData relationship,
    UserSearchResult linkedUser,
  ) async {
    final isCaregiver = _userRole == 'caregiver';
    final userData = LinkedUserData(
      relationshipId: relationship.id,
      userId: linkedUser.id,
      userName: linkedUser.name,
      userEmail: linkedUser.email,
      userPhone: linkedUser.phoneNumber,
      userCode: linkedUser.uniqueCode,
      isEditable: isCaregiver, // Caregiver can edit dependent's name
      linkedUserRole: linkedUser.role,
    );

    final result = await context.push<bool>(
      AppRoutes.linkedUserDetail,
      extra: userData,
    );

    if (result == true) {
      _loadLinkedUsers();
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.9,
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
            _buildThemeOption(
              'system',
              'System default',
              Icons.settings_suggest,
            ),
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
      trailing: isSelected
          ? const Icon(Icons.check, color: Colors.green)
          : null,
      onTap: () async {
        await _settingsRepository.setThemeMode(value);
        setState(() => _themeMode = value);
        if (mounted) Navigator.pop(context);
      },
    );
  }
}
