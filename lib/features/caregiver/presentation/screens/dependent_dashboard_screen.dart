import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../shared/widgets/widgets.dart';

/// Dashboard screen showing a dependent's reminders and status
class DependentDashboardScreen extends StatefulWidget {
  final String dependentId;

  const DependentDashboardScreen({
    super.key,
    required this.dependentId,
  });

  @override
  State<DependentDashboardScreen> createState() => _DependentDashboardScreenState();
}

class _DependentDashboardScreenState extends State<DependentDashboardScreen>
    with WidgetsBindingObserver {
  final _userApi = getIt<UserApi>();
  final _reminderApi = getIt<ReminderApi>();
  final _reminderInstanceApi = getIt<ReminderInstanceApi>();
  final _signalRService = getIt<SignalRService>();

  UserSearchResult? _dependent;
  List<ReminderData> _reminders = [];
  List<ReminderInstanceData> _todayInstances = [];
  bool _isLoading = true;
  bool _isInitialLoad = true;
  String? _activeStatusFilter; // null = show all, 'completed'/'pending'/'missed'

  List<ReminderInstanceData> get _filteredInstances {
    if (_activeStatusFilter == null) return _todayInstances;
    return _todayInstances.where((i) => i.status == _activeStatusFilter).toList();
  }

  void _toggleStatusFilter(String status) {
    setState(() {
      if (_activeStatusFilter == status) {
        _activeStatusFilter = null; // Tap same filter = clear
      } else {
        _activeStatusFilter = status; // Tap different filter = switch
      }
    });
  }

  StreamSubscription<SignalREvent>? _signalRSubscription;
  StreamSubscription<SignalRConnectionState>? _connectionStateSubscription;
  bool _isSignalRInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScreen();
  }

  /// Initialize screen with proper SignalR connection sequence
  Future<void> _initializeScreen() async {
    debugPrint('DependentDashboardScreen: Starting screen initialization for dependent ${widget.dependentId}');

    // 1. Set up connection state listener first (to handle reconnections)
    _setupConnectionStateListener();

    // 2. Ensure SignalR is connected (silent background connection with retry)
    await _ensureSignalRConnected();

    // 3. Subscribe to dependent's updates (MUST await to ensure subscription completes)
    await _subscribeToDependent();

    // 4. Set up event listeners (now guaranteed to receive events)
    _setupSignalRListeners();
    _isSignalRInitialized = true;
    debugPrint('DependentDashboardScreen: SignalR initialization complete');

    // 5. Load data (fresh data + real-time updates ready)
    _loadData();
  }

  /// Ensure SignalR is connected with automatic retry
  Future<void> _ensureSignalRConnected() async {
    debugPrint('DependentDashboardScreen: Ensuring SignalR connection...');
    debugPrint('DependentDashboardScreen: Current SignalR state: ${_signalRService.currentState}');

    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      final connected = await _signalRService.ensureConnected();

      if (connected) {
        debugPrint('DependentDashboardScreen: SignalR connected successfully on attempt $attempt');
        return;
      }

      debugPrint('DependentDashboardScreen: SignalR connection attempt $attempt/$maxRetries failed');

      if (attempt < maxRetries) {
        debugPrint('DependentDashboardScreen: Retrying in ${retryDelay.inSeconds} seconds...');
        await Future.delayed(retryDelay);
      }
    }

    debugPrint('DependentDashboardScreen: SignalR connection failed after $maxRetries attempts, continuing without real-time updates');
    // Continue anyway - user can still use pull-to-refresh
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _signalRSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _unsubscribeFromDependent();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('DependentDashboardScreen: App lifecycle state changed to $state');

    if (state == AppLifecycleState.resumed) {
      debugPrint('DependentDashboardScreen: App resumed from background');
      debugPrint('DependentDashboardScreen: Current SignalR state: ${_signalRService.currentState}');

      // Ensure SignalR is connected and subscription is active after resume
      _ensureSignalRConnected().then((_) async {
        // Re-subscribe in case the subscription was lost
        await _subscribeToDependent();
        debugPrint('DependentDashboardScreen: SignalR check complete after resume, refreshing data');
        _loadData();
      });
    } else if (state == AppLifecycleState.paused) {
      debugPrint('DependentDashboardScreen: App going to background');
    }
  }

  /// Subscribe to real-time updates for this dependent (for caregivers)
  Future<void> _subscribeToDependent() async {
    debugPrint('DependentDashboardScreen: Subscribing to dependent ${widget.dependentId}');
    debugPrint('DependentDashboardScreen: SignalR isConnected=${_signalRService.isConnected}');

    final success = await _signalRService.subscribeToDependent(widget.dependentId);

    if (success) {
      debugPrint('DependentDashboardScreen: Successfully subscribed to dependent ${widget.dependentId}');
    } else {
      debugPrint('DependentDashboardScreen: Subscription queued (SignalR not connected) for dependent ${widget.dependentId}');
    }
  }

  void _unsubscribeFromDependent() {
    debugPrint('DependentDashboardScreen: Unsubscribing from dependent ${widget.dependentId}');
    _signalRService.unsubscribeFromDependent(widget.dependentId);
  }

  void _setupConnectionStateListener() {
    debugPrint('DependentDashboardScreen: Setting up connection state listener');
    _connectionStateSubscription = _signalRService.connectionState.listen((state) {
      debugPrint('DependentDashboardScreen: SignalR connection state changed: $state');

      if (state == SignalRConnectionState.connected) {
        debugPrint('DependentDashboardScreen: Connection restored, refreshing data to sync missed updates');
        _loadData();

        // If SignalR wasn't initialized yet, set up listeners now
        if (!_isSignalRInitialized) {
          debugPrint('DependentDashboardScreen: Late initialization - setting up SignalR listeners after reconnection');
          _setupSignalRListeners();
          _isSignalRInitialized = true;
        }
      } else if (state == SignalRConnectionState.disconnected) {
        debugPrint('DependentDashboardScreen: SignalR disconnected - real-time updates paused');
      } else if (state == SignalRConnectionState.reconnecting) {
        debugPrint('DependentDashboardScreen: SignalR reconnecting...');
      }
    });
  }

  void _setupSignalRListeners() {
    // Avoid duplicate subscriptions
    if (_signalRSubscription != null) {
      debugPrint('DependentDashboardScreen: SignalR event listener already set up, skipping');
      return;
    }

    debugPrint('DependentDashboardScreen: Setting up SignalR event listeners');
    debugPrint('DependentDashboardScreen: SignalR isConnected=${_signalRService.isConnected}, state=${_signalRService.currentState}');
    debugPrint('DependentDashboardScreen: Subscribed dependents: ${_signalRService.subscribedDependents}');

    _signalRSubscription = _signalRService.events.listen((event) {
      debugPrint('DependentDashboardScreen: ========== SignalR EVENT RECEIVED ==========');
      debugPrint('DependentDashboardScreen: Event type: ${event.type}');
      debugPrint('DependentDashboardScreen: Event data: ${event.data}');
      debugPrint('DependentDashboardScreen: Event timestamp: ${event.timestamp}');
      debugPrint('DependentDashboardScreen: ============================================');

      // Refresh when dependent completes/snoozes a reminder or when instances change
      if (event.type == SignalREventType.instanceStatusChanged ||
          event.type == SignalREventType.instanceCreated ||
          event.type == SignalREventType.reminderCreated ||
          event.type == SignalREventType.reminderUpdated ||
          event.type == SignalREventType.reminderDeleted) {
        debugPrint('DependentDashboardScreen: Event matched! Triggering data refresh for ${event.type}');
        _loadData();
      } else {
        debugPrint('DependentDashboardScreen: Event ${event.type} not handled by this screen');
      }
    });

    debugPrint('DependentDashboardScreen: SignalR event listener registered successfully');
  }

  Future<void> _loadData() async {
    debugPrint('DependentDashboardScreen: _loadData() called for dependent ${widget.dependentId}');
    debugPrint('DependentDashboardScreen: isInitialLoad=$_isInitialLoad, SignalR state=${_signalRService.currentState}');

    // Only show loading indicator on initial load to avoid jarring screen flashes
    if (_isInitialLoad) {
      setState(() => _isLoading = true);
    }

    try {
      _dependent = await _userApi.getById(widget.dependentId);
      debugPrint('DependentDashboardScreen: Dependent loaded: ${_dependent?.name}');

      _reminders = await _reminderApi.getReminders(dependentId: widget.dependentId);
      debugPrint('DependentDashboardScreen: Loaded ${_reminders.length} reminders');

      _todayInstances = await _reminderInstanceApi.getInstances(
        dependentId: widget.dependentId,
        date: DateTime.now(),
      );
      debugPrint('DependentDashboardScreen: Loaded ${_todayInstances.length} instances for today');

      // Log instance statuses for debugging
      final statusCounts = <String, int>{};
      for (final instance in _todayInstances) {
        statusCounts[instance.status] = (statusCounts[instance.status] ?? 0) + 1;
      }
      debugPrint('DependentDashboardScreen: Instance statuses: $statusCounts');

      debugPrint('DependentDashboardScreen: Data load completed successfully');
    } catch (e) {
      debugPrint('DependentDashboardScreen: Error loading data: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isInitialLoad = false;
      });
      debugPrint('DependentDashboardScreen: UI state updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_dependent?.name ?? 'Dependent'),
        actions: [
          IconButton(
            icon: const Icon(Icons.contacts),
            onPressed: () => context.goToEmergencyContacts(widget.dependentId),
            tooltip: 'Emergency Contacts',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // Summary header
                  SliverToBoxAdapter(
                    child: _buildSummaryHeader(),
                  ),
                  // Today's reminders
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: AppSpacing.screenPaddingHorizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Today\'s Reminders',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_activeStatusFilter != null)
                            GestureDetector(
                              onTap: () => setState(() => _activeStatusFilter = null),
                              child: Text(
                                'Clear filter',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_filteredInstances.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: AppSpacing.screenPadding,
                        child: _activeStatusFilter != null
                            ? _NoFilterResultsCard(status: _activeStatusFilter!)
                            : _EmptyRemindersCard(),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: AppSpacing.screenPaddingHorizontal,
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final instance = _filteredInstances[index];
                            final reminder = _reminders.firstWhere(
                              (r) => r.id == instance.reminderId,
                              orElse: () => _reminders.first,
                            );
                            return _buildReminderCard(reminder, instance);
                          },
                          childCount: _filteredInstances.length,
                        ),
                      ),
                    ),
                  // All reminders section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.md,
                        right: AppSpacing.md,
                        top: AppSpacing.lg,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'All Reminders',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final result = await context.goToAddReminder(widget.dependentId);
                              if (result == true) _loadData();
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_reminders.isEmpty)
                    SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.notifications_off_outlined,
                        title: 'No Reminders',
                        message: 'Create a reminder to help ${_dependent?.name ?? 'your dependent'} stay on track.',
                        actionLabel: 'Add Reminder',
                        onAction: () async {
                          final result = await context.goToAddReminder(widget.dependentId);
                          if (result == true) _loadData();
                        },
                      ),
                    )
                  else
                    SliverPadding(
                      padding: AppSpacing.screenPadding,
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final reminder = _reminders[index];
                            return _buildReminderTemplateCard(reminder);
                          },
                          childCount: _reminders.length,
                        ),
                      ),
                    ),
                  // Bottom padding
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 80),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.goToAddReminder(widget.dependentId);
          if (result == true) _loadData();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Reminder'),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final completed = _todayInstances.where((i) => i.status == 'completed').length;
    final pending = _todayInstances.where((i) => i.status == 'pending').length;
    final missed = _todayInstances.where((i) => i.status == 'missed').length;

    return Container(
      margin: AppSpacing.screenPadding,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            label: 'Completed',
            value: completed.toString(),
            color: AppColors.success,
            isSelected: _activeStatusFilter == 'completed',
            onTap: () => _toggleStatusFilter('completed'),
          ),
          _StatItem(
            label: 'Pending',
            value: pending.toString(),
            color: AppColors.warning,
            isSelected: _activeStatusFilter == 'pending',
            onTap: () => _toggleStatusFilter('pending'),
          ),
          _StatItem(
            label: 'Missed',
            value: missed.toString(),
            color: AppColors.error,
            isSelected: _activeStatusFilter == 'missed',
            onTap: () => _toggleStatusFilter('missed'),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(ReminderData reminder, ReminderInstanceData instance) {
    final status = switch (instance.status) {
      'completed' => ReminderStatus.completed,
      'missed' => ReminderStatus.missed,
      'snoozed' => ReminderStatus.snoozed,
      _ => ReminderStatus.pending,
    };

    // For pending instances, use reminder template time (hour/minute are stored in local time)
    // For completed/missed instances, convert UTC scheduledTime to local time for display
    final localScheduledTime = instance.scheduledTime.toLocal();
    final displayTime = instance.status == 'pending'
        ? DateTime(
            localScheduledTime.year,
            localScheduledTime.month,
            localScheduledTime.day,
            reminder.hour,
            reminder.minute,
          )
        : localScheduledTime;
    final time = DateFormat.jm().format(displayTime);

    return ReminderCard(
      title: reminder.title,
      time: time,
      status: status,
      subtitle: reminder.description,
      hasVoiceNote: reminder.voiceNoteUrl != null,
      priority: reminder.priority == 'high'
          ? ReminderPriority.high
          : ReminderPriority.normal,
      onTap: () async {
        final result = await context.goToEditReminder(reminder.id);
        if (result == true) _loadData();
      },
    );
  }

  Widget _buildReminderTemplateCard(ReminderData reminder) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final time = '${reminder.hour.toString().padLeft(2, '0')}:${reminder.minute.toString().padLeft(2, '0')}';
    final repeatLabel = switch (reminder.repeatPattern) {
      'once' => 'Once',
      'daily' => 'Daily',
      'weekly' => 'Weekly',
      'specific_days' => 'Specific days',
      _ => reminder.repeatPattern,
    };

    return AccessibleCard(
      onTap: () async {
        final result = await context.goToEditReminder(reminder.id);
        if (result == true) _loadData();
      },
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              reminder.voiceNoteUrl != null
                  ? Icons.mic
                  : Icons.notifications_active,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$time • $repeatLabel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (reminder.priority == 'high')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'HIGH',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            Icons.chevron_right,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isSelected ? 0.4 : 0.2),
              shape: BoxShape.circle,
              border: isSelected ? Border.all(color: color, width: 2) : null,
            ),
            child: Center(
              child: Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRemindersCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available,
            size: 48,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No reminders for today',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoFilterResultsCard extends StatelessWidget {
  final String status;

  const _NoFilterResultsCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final statusLabel = status[0].toUpperCase() + status.substring(1);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Icon(
            Icons.filter_list_off,
            size: 48,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No $statusLabel reminders today',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
