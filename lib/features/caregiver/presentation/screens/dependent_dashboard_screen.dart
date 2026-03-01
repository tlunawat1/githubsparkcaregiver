import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/custom_icons.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/category_inference.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../shared/widgets/redesign_ui.dart';
import '../../../../shared/widgets/widgets.dart';

/// Dashboard screen showing a dependent's reminders and status
/// Features a redesigned layout with greeting, progress bar, and timeline view
class DependentDashboardScreen extends StatefulWidget {
  final String dependentId;

  const DependentDashboardScreen({super.key, required this.dependentId});

  @override
  State<DependentDashboardScreen> createState() =>
      _DependentDashboardScreenState();
}

class _DependentDashboardScreenState extends State<DependentDashboardScreen>
    with WidgetsBindingObserver {
  final _userApi = getIt<UserApi>();
  final _reminderApi = getIt<ReminderApi>();
  final _reminderInstanceApi = getIt<ReminderInstanceApi>();
  final _signalRService = getIt<SignalRService>();
  final _settingsRepository = getIt<SettingsRepository>();

  UserSearchResult? _dependent;
  List<ReminderData> _reminders = [];
  List<ReminderInstanceData> _todayInstances = [];
  bool _isLoading = true;
  bool _isInitialLoad = true;
  String? _activeStatusFilter;
  int _lastDismissedMissedCount = 0; // Track count when dismissed

  List<ReminderInstanceData> get _filteredInstances {
    if (_activeStatusFilter == null) return _todayInstances;
    return _todayInstances
        .where((i) => i.status == _activeStatusFilter)
        .toList();
  }

  List<ReminderInstanceData> get _sortedFilteredInstances {
    return List<ReminderInstanceData>.from(_filteredInstances)..sort((a, b) {
      final aPending = a.status == 'pending';
      final bPending = b.status == 'pending';
      if (aPending != bPending) {
        return aPending ? -1 : 1; // Pending items always appear first.
      }
      if (aPending && bPending) {
        return a.scheduledTime.compareTo(b.scheduledTime); // Soonest first.
      }
      return b.scheduledTime.compareTo(a.scheduledTime); // Others newest first.
    });
  }

  // Computed stats
  int get _completedCount =>
      _todayInstances.where((i) => i.status == 'completed').length;
  int get _totalCount => _todayInstances.length;

  // Get urgent items (missed or pending that should have happened)
  List<ReminderInstanceData> get _urgentItems {
    final now = DateTime.now();
    return _todayInstances.where((i) {
      if (i.status == 'missed') {
        return true;
      }
      if (i.status == 'pending' && i.scheduledTime.toLocal().isBefore(now)) {
        return true;
      }
      return false;
    }).toList();
  }

  void _toggleStatusFilter(String status) {
    Haptics.selectionClick();
    setState(() {
      if (_activeStatusFilter == status) {
        _activeStatusFilter = null;
      } else {
        _activeStatusFilter = status;
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

  Future<void> _initializeScreen() async {
    // Pre-load animation settings for synchronous access
    await _settingsRepository.isReduceAnimationsEnabled();

    _setupConnectionStateListener();
    await _ensureSignalRConnected();
    await _subscribeToDependent();
    _setupSignalRListeners();
    _isSignalRInitialized = true;
    _loadData();
  }

  Future<void> _ensureSignalRConnected() async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      final connected = await _signalRService.ensureConnected();
      if (connected) return;
      if (attempt < maxRetries) {
        await Future.delayed(retryDelay);
      }
    }
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
      _ensureSignalRConnected().then((_) async {
        await _subscribeToDependent();
        _loadData();
      });
    }
  }

  Future<void> _subscribeToDependent() async {
    await _signalRService.subscribeToDependent(widget.dependentId);
  }

  void _unsubscribeFromDependent() {
    _signalRService.unsubscribeFromDependent(widget.dependentId);
  }

  void _setupConnectionStateListener() {
    _connectionStateSubscription = _signalRService.connectionState.listen((
      state,
    ) {
      if (state == SignalRConnectionState.connected) {
        _loadData();
        if (!_isSignalRInitialized) {
          _setupSignalRListeners();
          _isSignalRInitialized = true;
        }
      }
    });
  }

  void _setupSignalRListeners() {
    if (_signalRSubscription != null) return;

    _signalRSubscription = _signalRService.events.listen((event) {
      if (event.type == SignalREventType.instanceStatusChanged ||
          event.type == SignalREventType.instanceCreated ||
          event.type == SignalREventType.reminderCreated ||
          event.type == SignalREventType.reminderUpdated ||
          event.type == SignalREventType.reminderDeleted) {
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    if (_isInitialLoad) {
      setState(() => _isLoading = true);
    }

    try {
      _dependent = await _userApi.getById(widget.dependentId);
      _reminders = await _reminderApi.getReminders(
        dependentId: widget.dependentId,
      );
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

    return Scaffold(
      body: RedesignBackground(
        child: SafeArea(
          child: _isLoading
              ? _buildSkeletonLoading()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.sm,
                          ),
                          child: Row(
                            children: [
                              IconButton.filledTonal(
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  _dependent?.name ?? 'Dashboard',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton.filledTonal(
                                onPressed: () => context.goToEmergencyContacts(
                                  widget.dependentId,
                                ),
                                icon: const Icon(
                                  Icons.contact_emergency_outlined,
                                ),
                                tooltip: 'Emergency Contacts',
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(child: _buildHeader()),
                      if (_urgentItems.isNotEmpty)
                        SliverToBoxAdapter(child: _buildUrgentSection()),
                      SliverToBoxAdapter(child: _buildQuickStats()),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.md,
                            AppSpacing.sm,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Today\'s Schedule',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  letterSpacing: 1.0,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextButton(
                                onPressed: _activeStatusFilter == null
                                    ? null
                                    : () {
                                        setState(() {
                                          _activeStatusFilter = null;
                                        });
                                      },
                                child: const Text('Clear'),
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
                                ? _NoFilterResultsCard(
                                    status: _activeStatusFilter!,
                                  )
                                : _EmptyRemindersCard(),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: AppSpacing.screenPaddingHorizontal,
                          sliver: SliverList.builder(
                            itemCount: _sortedFilteredInstances.length,
                            itemBuilder: (context, index) {
                              final instance = _sortedFilteredInstances[index];
                              return _buildScheduleCard(instance);
                            },
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.lg,
                            AppSpacing.md,
                            AppSpacing.sm,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'All Reminders',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  final result = await context.goToAddReminder(
                                    widget.dependentId,
                                  );
                                  if (result == true) {
                                    _loadData();
                                  }
                                },
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Add'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_reminders.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: AppSpacing.screenPadding,
                            child: EmptyState(
                              icon: Icons.notifications_off_outlined,
                              title: 'No Reminders',
                              message:
                                  'Create a reminder to help ${_dependent?.name ?? 'your dependent'} stay on track.',
                              actionLabel: 'Add Reminder',
                              onAction: () async {
                                final result = await context.goToAddReminder(
                                  widget.dependentId,
                                );
                                if (result == true) {
                                  _loadData();
                                }
                              },
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: AppSpacing.screenPaddingHorizontal,
                          sliver: SliverList.builder(
                            itemCount: _reminders.length,
                            itemBuilder: (context, index) {
                              return _buildAllReminderTemplateCard(
                                _reminders[index],
                              );
                            },
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  ),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.goToAddReminder(widget.dependentId);
          if (result == true) _loadData();
        },
        icon: Icon(AppIcons.add),
        label: const Text('Add Reminder'),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final completion = _totalCount == 0 ? 0.0 : _completedCount / _totalCount;
    final percent = (completion * 100).round();

    return GlassCard(
      margin: AppSpacing.screenPadding,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today\'s Progress',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '$_completedCount of $_totalCount done',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Text(
                '$percent%',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: completion.clamp(0.0, 1.0),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: Colors.teal),
              const SizedBox(width: 6),
              Text(
                percent >= 50
                    ? 'Halfway there! Keep it up!'
                    : 'Great start! Keep going!',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUrgentSection() {
    final theme = Theme.of(context);
    final urgentCount = _urgentItems.length;

    // Only show if there are urgent items AND (never dismissed OR count increased)
    if (urgentCount <= _lastDismissedMissedCount) {
      return const SizedBox.shrink();
    }

    return GlassCard(
      margin: AppSpacing.screenPaddingHorizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(AppIcons.priorityHigh, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              urgentCount == 1
                  ? '1 Reminder needs attention!!'
                  : '$urgentCount Reminders need attention!!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Close button
          IconButton(
            icon: Icon(Icons.close_rounded, color: AppColors.error, size: 20),
            onPressed: () {
              Haptics.lightImpact();
              setState(() {
                _lastDismissedMissedCount = urgentCount;
              });
            },
            tooltip: 'Dismiss',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: _FilterPill(
              label: 'Done',
              isSelected: _activeStatusFilter == 'completed',
              onTap: () => _toggleStatusFilter('completed'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _FilterPill(
              label: 'Pending',
              isSelected: _activeStatusFilter == 'pending',
              onTap: () => _toggleStatusFilter('pending'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _FilterPill(
              label: 'Missed',
              isSelected: _activeStatusFilter == 'missed',
              onTap: () => _toggleStatusFilter('missed'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(ReminderInstanceData instance) {
    final theme = Theme.of(context);
    final reminder = _reminders.cast<ReminderData?>().firstWhere(
      (r) => r?.id == instance.reminderId,
      orElse: () => null,
    );
    final title = reminder?.title ?? instance.reminderTitle ?? 'Reminder';
    final category = CategoryInference.inferCategory(title);
    final icon = AppIcons.getCategoryIcon(category);
    final iconColor = AppIcons.getCategoryColor(category);
    final time = TimeOfDay.fromDateTime(
      instance.scheduledTime.toLocal(),
    ).format(context);
    final repeatLabel = reminder == null
        ? 'Scheduled'
        : switch (reminder.repeatPattern) {
            'once' => 'Once',
            'daily' => 'Daily',
            'weekly' => 'Weekly',
            'specific_days' => 'Specific days',
            _ => reminder.repeatPattern,
          };
    final statusColor = switch (instance.status) {
      'completed' => Colors.green,
      'missed' => Colors.redAccent,
      'pending' => theme.colorScheme.primary,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    final statusLabel = switch (instance.status) {
      'completed' => 'Done',
      'missed' => 'Missed',
      'pending' => 'Pending',
      _ => 'Next',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: () async {
          final result = await context.goToEditReminder(instance.reminderId);
          if (result == true) {
            _loadData();
          }
        },
        child: GlassCard(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$time • $repeatLabel',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllReminderTemplateCard(ReminderData reminder) {
    final theme = Theme.of(context);
    final category = CategoryInference.inferCategory(reminder.title);
    final icon = AppIcons.getCategoryIcon(category);
    final iconColor = AppIcons.getCategoryColor(category);
    final time =
        '${reminder.hour.toString().padLeft(2, '0')}:${reminder.minute.toString().padLeft(2, '0')}';
    final repeatLabel = switch (reminder.repeatPattern) {
      'once' => 'Once',
      'daily' => 'Daily',
      'weekly' => 'Weekly',
      'specific_days' => 'Specific days',
      _ => reminder.repeatPattern,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GestureDetector(
        onTap: () async {
          final result = await context.goToEditReminder(reminder.id);
          if (result == true) {
            _loadData();
          }
        },
        child: GlassCard(
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$time • $repeatLabel',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (reminder.priority == 'high')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'HIGH',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build skeleton loading state
  Widget _buildSkeletonLoading() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return CustomScrollView(
      slivers: [
        // Header skeleton with progress bar placeholder
        SliverToBoxAdapter(
          child: Container(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress bar skeleton
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: AppRadius.largeRadius,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Quick stats skeleton
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: Row(
              children: List.generate(3, (index) {
                return Expanded(
                  child: Container(
                    height: 48,
                    margin: EdgeInsets.only(
                      left: index > 0 ? AppSpacing.sm : 0,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),

        // Today's schedule header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(
              'Today\'s Schedule',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Timeline skeleton
        SliverPadding(
          padding: AppSpacing.screenPaddingHorizontal,
          sliver: SliverToBoxAdapter(
            child: const TimelineSkeletonList(itemCount: 4),
          ),
        ),

        // All reminders header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(
              'All Reminders',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Reminder cards skeleton
        SliverPadding(
          padding: AppSpacing.screenPadding,
          sliver: SliverToBoxAdapter(
            child: Column(
              children: List.generate(3, (index) {
                return Container(
                  height: 72,
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: AppRadius.mediumRadius,
                  ),
                );
              }),
            ),
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isSelected
                  ? Colors.white
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
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
        gradient: AppColors.completedGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_available_rounded,
              color: AppColors.success,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All caught up!',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'No reminders scheduled for today',
                  style: theme.textTheme.bodyMedium?.copyWith(
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
      child: Row(
        children: [
          Icon(
            Icons.filter_list_off_rounded,
            size: 48,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No $statusLabel Reminders',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'There are no $status reminders for today',
                  style: theme.textTheme.bodyMedium?.copyWith(
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
