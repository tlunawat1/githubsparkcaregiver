import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../data/datasources/local/database.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/link_request_banner.dart';
import '../widgets/link_request_dialog.dart';

/// Home screen for dependents showing reminders and SOS button
class DependentHomeScreen extends StatefulWidget {
  const DependentHomeScreen({super.key});

  @override
  State<DependentHomeScreen> createState() => _DependentHomeScreenState();
}

class _DependentHomeScreenState extends State<DependentHomeScreen>
    with WidgetsBindingObserver {
  final _userApi = getIt<UserApi>();
  final _userRepository = getIt<UserRepository>();
  final _reminderApi = getIt<ReminderApi>();
  final _reminderInstanceApi = getIt<ReminderInstanceApi>();
  final _settingsRepository = getIt<SettingsRepository>();
  final _careRelationshipRepository = getIt<CareRelationshipRepository>();
  final _signalRService = getIt<SignalRService>();

  UserData? _user;
  List<ReminderData> _reminders = [];
  List<ReminderInstanceData> _todayInstances = [];
  List<CareRelationship> _pendingLinks = [];
  Map<String, User> _pendingLinkCaregivers = {};
  bool _isLoading = true;
  bool _isInitialLoad = true;
  String _themeMode = 'system';
  Set<String> _completingInstances = {};
  StreamSubscription<SignalREvent>? _signalRSubscription;
  StreamSubscription<SignalRConnectionState>? _connectionStateSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _setupSignalRListeners();
    _setupConnectionStateListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _signalRSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('DependentHomeScreen: App resumed, refreshing data');
      // Refresh data when app comes to foreground
      // SignalR connection will be handled by app-level lifecycle observer
      _loadData();
    }
  }

  void _setupConnectionStateListener() {
    _connectionStateSubscription = _signalRService.connectionState.listen((state) {
      debugPrint('DependentHomeScreen: SignalR connection state changed to $state');
      
      if (state == SignalRConnectionState.connected) {
        // Connection restored - refresh data to get any updates we missed
        debugPrint('DependentHomeScreen: Connection restored, refreshing data');
        _loadData();
      }
    });
  }

  void _setupSignalRListeners() {
    debugPrint('DependentHomeScreen: Setting up SignalR listeners');
    debugPrint('DependentHomeScreen: SignalR isConnected=${_signalRService.isConnected}');

    _signalRSubscription = _signalRService.events.listen((event) {
      debugPrint('DependentHomeScreen: Received SignalR event: ${event.type}');
      if (event.type == SignalREventType.instanceCreated ||
          event.type == SignalREventType.instanceStatusChanged ||
          event.type == SignalREventType.reminderCreated ||
          event.type == SignalREventType.reminderUpdated ||
          event.type == SignalREventType.reminderDeleted ||
          event.type == SignalREventType.linkVerified ||
          event.type == SignalREventType.linkRequestReceived) {
        debugPrint('DependentHomeScreen: Refreshing data due to ${event.type}');
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    // Only show loading indicator on initial load to avoid jarring screen flashes
    if (_isInitialLoad) {
      setState(() => _isLoading = true);
    }

    try {
      _themeMode = await _settingsRepository.getThemeMode();
      // Load current user from remote API
      _user = await _userApi.getCurrentUser();

      if (_user != null) {
        final userId = _user!.id;
        _reminders = await _reminderApi.getReminders(dependentId: userId);
        _todayInstances = await _reminderInstanceApi.getInstances(
          dependentId: userId,
          date: DateTime.now(),
        );

        // Load pending link requests
        _pendingLinks = await _careRelationshipRepository
            .getPendingLinksForDependent(userId);

        // Load caregiver info for each pending link
        _pendingLinkCaregivers = {};
        for (final link in _pendingLinks) {
          final caregiver =
              await _userRepository.getUserById(link.caregiverId);
          if (caregiver != null) {
            _pendingLinkCaregivers[link.id] = caregiver;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isInitialLoad = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const LoadingIndicator(message: 'Loading...')
            : Stack(
                children: [
                  // Main scrollable content
                  RefreshIndicator(
                    onRefresh: _loadData,
                    child: CustomScrollView(
                      slivers: [
                        // Header
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: AppSpacing.screenPadding,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$greeting,',
                                            style: theme.textTheme.titleLarge?.copyWith(
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          Text(
                                            _user?.name ?? 'Friend',
                                            style: theme.textTheme.displaySmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.settings, size: 28),
                                      onPressed: () => _showSettingsBottomSheet(context),
                                      tooltip: 'Settings',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  DateFormat('EEEE, MMMM d').format(now),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (_user?.uniqueCode != null &&
                                    _user!.uniqueCode.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  _buildUniqueCodeCard(),
                                ],
                                // Pending link request banners
                                if (_pendingLinks.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  ..._pendingLinks.map((link) {
                                    final caregiver =
                                        _pendingLinkCaregivers[link.id];
                                    if (caregiver == null) {
                                      return const SizedBox.shrink();
                                    }
                                    return LinkRequestBanner(
                                      caregiver: caregiver,
                                      relationship: link,
                                      onTap: () =>
                                          _showLinkRequestDialog(link, caregiver),
                                    );
                                  }),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // Today's reminders
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              AppSpacing.lg,
                              AppSpacing.md,
                              AppSpacing.sm,
                            ),
                            child: Text(
                              'Today\'s Reminders',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        // Reminder grid or empty state
                        if (_todayInstances.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: AppSpacing.screenPadding,
                              child: _buildNoRemindersCard(),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: AppSpacing.screenPaddingHorizontal,
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: AppSpacing.md,
                                crossAxisSpacing: AppSpacing.md,
                                childAspectRatio: 0.95,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final sortedReminders = _getSortedReminders();
                                  if (index >= sortedReminders.length) return null;

                                  final instance = sortedReminders[index];
                                  final reminder = _reminders.cast<ReminderData?>().firstWhere(
                                    (r) => r?.id == instance.reminderId,
                                    orElse: () => null,
                                  );

                                  // For pending instances, use reminder template time (hour/minute are in local time)
                                  // For completed/missed instances, convert UTC scheduledTime to local time
                                  final localScheduledTime = instance.scheduledTime.toLocal();
                                  final displayTime = instance.status == 'pending' && reminder != null
                                      ? DateTime(
                                          localScheduledTime.year,
                                          localScheduledTime.month,
                                          localScheduledTime.day,
                                          reminder.hour,
                                          reminder.minute,
                                        )
                                      : localScheduledTime;

                                  return ReminderButton(
                                    title: reminder?.title ??
                                        instance.reminderTitle ??
                                        'Reminder',
                                    time: DateFormat.jm().format(displayTime),
                                    status: _getInstanceStatus(instance.status),
                                    hasVoiceNote: (reminder?.voiceNoteUrl ??
                                            instance.voiceNoteUrl) !=
                                        null,
                                    isLoading:
                                        _completingInstances.contains(instance.id),
                                    onTap: () => _markInstanceComplete(instance.id),
                                    onDetailsTap: () =>
                                        _showDetailsModal(instance, reminder),
                                  );
                                },
                                childCount: _getSortedReminders().length,
                              ),
                            ),
                          ),

                        // Spacer for SOS button
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 200),
                        ),
                      ],
                    ),
                  ),
                  // SOS button fixed at bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: SOSButton(
                          onActivated: () {
                            context.go('${AppRoutes.dependentHome}/sos');
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Get all reminders sorted: pending first, then missed, then completed
  List<ReminderInstanceData> _getSortedReminders() {
    final sorted = List<ReminderInstanceData>.from(_todayInstances);
    sorted.sort((a, b) {
      // Priority order: pending > snoozed > missed > completed
      const statusOrder = {
        'pending': 0,
        'snoozed': 1,
        'missed': 2,
        'completed': 3,
      };
      final aOrder = statusOrder[a.status] ?? 4;
      final bOrder = statusOrder[b.status] ?? 4;
      if (aOrder != bOrder) return aOrder.compareTo(bOrder);
      // Within same status, sort by scheduled time
      return a.scheduledTime.compareTo(b.scheduledTime);
    });
    return sorted;
  }

  ReminderInstanceStatus _getInstanceStatus(String status) {
    return switch (status) {
      'completed' => ReminderInstanceStatus.completed,
      'missed' => ReminderInstanceStatus.missed,
      'snoozed' => ReminderInstanceStatus.snoozed,
      _ => ReminderInstanceStatus.pending,
    };
  }

  Future<void> _markInstanceComplete(String instanceId) async {
    if (_completingInstances.contains(instanceId)) return;

    setState(() => _completingInstances.add(instanceId));
    HapticFeedback.mediumImpact();

    try {
      await _reminderInstanceApi.markCompleted(instanceId);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Great job! Reminder completed.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error completing reminder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _completingInstances.remove(instanceId));
      }
    }
  }

  Future<void> _snoozeInstance(String instanceId) async {
    HapticFeedback.lightImpact();

    try {
      final snoozeUntil = DateTime.now().add(const Duration(minutes: 10));
      await _reminderInstanceApi.snooze(instanceId, snoozeUntil);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Snoozed for 10 minutes'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error snoozing reminder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showDetailsModal(ReminderInstanceData instance, ReminderData? reminder) {
    ReminderDetailsModal.show(
      context,
      title: reminder?.title ?? instance.reminderTitle ?? 'Reminder',
      scheduledTime: instance.scheduledTime.toLocal(),
      status: _getInstanceStatus(instance.status),
      description: reminder?.description ?? instance.reminderDescription,
      voiceNoteUrl: reminder?.voiceNoteUrl ?? instance.voiceNoteUrl,
      onMarkDone: () => _markInstanceComplete(instance.id),
      onSnooze: () => _snoozeInstance(instance.id),
    );
  }

  String _getGreeting(int hour) {
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  Widget _buildNoRemindersCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.success, width: 2),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'All done for now!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No pending reminders. Enjoy your day!',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showLinkRequestDialog(CareRelationship relationship, User caregiver) {
    showDialog(
      context: context,
      builder: (context) => LinkRequestDialog(
        caregiver: caregiver,
        relationship: relationship,
        onAccepted: _loadData,
        onDeclined: _loadData,
      ),
    );
  }

  Widget _buildUniqueCodeCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final uniqueCode = _user?.uniqueCode ?? '';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.qr_code, color: colorScheme.secondary, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Code',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  uniqueCode,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: uniqueCode));
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
        ],
      ),
    );
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
                title: const Text('Switch to Caregiver'),
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
            const Text('Switch to Caregiver?'),
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
              '• You will see the Caregiver interface\n• You can manage dependents and reminders\n• You can switch back anytime',
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
              await _settingsRepository.setUserRole('caregiver');
              Navigator.pop(dialogContext);
              if (mounted) {
                // Use the widget's context for navigation after dialog is closed
                GoRouter.of(this.context).go(AppRoutes.caregiverHome);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
            ),
            child: const Text('Switch to Caregiver'),
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
