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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _setupSignalRListeners();
    _setupConnectionStateListener();
    _subscribeToDependent();
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
    if (state == AppLifecycleState.resumed) {
      debugPrint('DependentDashboardScreen: App resumed, refreshing data');
      _loadData();
      // Subscription will be restored by SignalRService automatically
    }
  }

  void _subscribeToDependent() {
    // Subscribe to real-time updates for this dependent
    // The SignalRService now tracks this subscription for restoration
    debugPrint('DependentDashboardScreen: Subscribing to dependent ${widget.dependentId}');
    _signalRService.subscribeToDependent(widget.dependentId);
  }

  void _unsubscribeFromDependent() {
    // Unsubscribe when leaving the screen
    debugPrint('DependentDashboardScreen: Unsubscribing from dependent ${widget.dependentId}');
    _signalRService.unsubscribeFromDependent(widget.dependentId);
  }

  void _setupConnectionStateListener() {
    _connectionStateSubscription = _signalRService.connectionState.listen((state) {
      debugPrint('DependentDashboardScreen: SignalR connection state changed to $state');
      
      if (state == SignalRConnectionState.connected) {
        // Connection restored - subscription will be auto-restored by SignalRService
        // Refresh data to ensure we have latest
        debugPrint('DependentDashboardScreen: Connection restored, refreshing data');
        _loadData();
      }
    });
  }

  void _setupSignalRListeners() {
    _signalRSubscription = _signalRService.events.listen((event) {
      debugPrint('DependentDashboardScreen: Received SignalR event: ${event.type}');
      // Refresh when dependent completes/snoozes a reminder or when instances change
      if (event.type == SignalREventType.instanceStatusChanged ||
          event.type == SignalREventType.instanceCreated ||
          event.type == SignalREventType.reminderCreated ||
          event.type == SignalREventType.reminderUpdated ||
          event.type == SignalREventType.reminderDeleted) {
        debugPrint('DependentDashboardScreen: Refreshing data due to ${event.type}');
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
      _dependent = await _userApi.getById(widget.dependentId);
      _reminders = await _reminderApi.getReminders(dependentId: widget.dependentId);
      _todayInstances = await _reminderInstanceApi.getInstances(
        dependentId: widget.dependentId,
        date: DateTime.now(),
      );
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
