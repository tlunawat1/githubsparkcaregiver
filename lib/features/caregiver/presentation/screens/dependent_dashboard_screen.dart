import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/custom_icons.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/animation_settings.dart';
import '../../../../core/utils/category_inference.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../shared/widgets/widgets.dart';

/// Dashboard screen showing a dependent's reminders and status
/// Features a redesigned layout with greeting, progress bar, and timeline view
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
  final _settingsRepository = getIt<SettingsRepository>();

  UserSearchResult? _dependent;
  List<ReminderData> _reminders = [];
  List<ReminderInstanceData> _todayInstances = [];
  bool _isLoading = true;
  bool _isInitialLoad = true;
  String? _activeStatusFilter;

  List<ReminderInstanceData> get _filteredInstances {
    if (_activeStatusFilter == null) return _todayInstances;
    return _todayInstances.where((i) => i.status == _activeStatusFilter).toList();
  }

  // Computed stats
  int get _completedCount => _todayInstances.where((i) => i.status == 'completed').length;
  int get _pendingCount => _todayInstances.where((i) => i.status == 'pending').length;
  int get _missedCount => _todayInstances.where((i) => i.status == 'missed').length;
  int get _totalCount => _todayInstances.length;

  // Get urgent items (missed or pending that should have happened)
  List<ReminderInstanceData> get _urgentItems {
    final now = DateTime.now();
    return _todayInstances.where((i) {
      if (i.status == 'missed') return true;
      if (i.status == 'pending' && i.scheduledTime.toLocal().isBefore(now)) return true;
      return false;
    }).toList();
  }

  void _toggleStatusFilter(String status) {
    HapticFeedback.selectionClick();
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
    _connectionStateSubscription = _signalRService.connectionState.listen((state) {
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_dependent?.name ?? 'Dashboard'),
        actions: [
          IconButton(
            icon: Icon(AppIcons.emergencyContact),
            onPressed: () => context.goToEmergencyContacts(widget.dependentId),
            tooltip: 'Emergency Contacts',
          ),
        ],
      ),
      body: _isLoading
          ? _buildSkeletonLoading()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // Header with greeting and progress
                  SliverToBoxAdapter(
                    child: _buildHeader(),
                  ),

                  // Urgent section (if there are missed/overdue items)
                  if (_urgentItems.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildUrgentSection(),
                    ),

                  // Quick stats (tappable filters)
                  SliverToBoxAdapter(
                    child: _buildQuickStats(),
                  ),

                  // Today's schedule section
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
                            _activeStatusFilter != null
                                ? '${_activeStatusFilter![0].toUpperCase()}${_activeStatusFilter!.substring(1)} Reminders'
                                : 'Today\'s Schedule',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_activeStatusFilter != null)
                            TextButton(
                              onPressed: () => setState(() => _activeStatusFilter = null),
                              child: Text('Clear'),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Timeline or filtered list
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
                      sliver: SliverToBoxAdapter(
                        child: _buildTimelineView(),
                      ),
                    ),

                  // All reminders section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xl,
                        AppSpacing.md,
                        AppSpacing.sm,
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
                            icon: Icon(AppIcons.add),
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
                            final card = _buildReminderTemplateCard(reminder);

                            // Apply staggered animation if enabled
                            if (AnimationSettings.shouldAnimate(context)) {
                              return card
                                  .animate()
                                  .fadeIn(
                                    duration: 200.ms,
                                    delay: (index * 50).ms,
                                  )
                                  .slideX(
                                    begin: 0.05,
                                    end: 0,
                                    duration: 200.ms,
                                    delay: (index * 50).ms,
                                    curve: Curves.easeOut,
                                  );
                            }
                            return card;
                          },
                          childCount: _reminders.length,
                        ),
                      ),
                    ),

                  // Bottom padding
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
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
    return Container(
      padding: AppSpacing.screenPadding,
      child: DailyProgressBar(
        completed: _completedCount,
        total: _totalCount,
      ),
    );
  }

  Widget _buildUrgentSection() {
    final theme = Theme.of(context);

    return Container(
      margin: AppSpacing.screenPaddingHorizontal,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: AppColors.missedGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.priorityHigh,
                color: AppColors.error,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Needs Attention',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_urgentItems.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _urgentItems.length == 1
                ? '1 reminder needs attention'
                : '${_urgentItems.length} reminders need attention',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.errorDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatChip(
              label: 'Done',
              value: _completedCount,
              color: AppColors.success,
              isSelected: _activeStatusFilter == 'completed',
              onTap: () => _toggleStatusFilter('completed'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _StatChip(
              label: 'Pending',
              value: _pendingCount,
              color: AppColors.warning,
              isSelected: _activeStatusFilter == 'pending',
              onTap: () => _toggleStatusFilter('pending'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _StatChip(
              label: 'Missed',
              value: _missedCount,
              color: AppColors.error,
              isSelected: _activeStatusFilter == 'missed',
              onTap: () => _toggleStatusFilter('missed'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineView() {
    final timelineItems = _filteredInstances.map((instance) {
      final reminder = _reminders.firstWhere(
        (r) => r.id == instance.reminderId,
        orElse: () => _reminders.first,
      );

      return TimelineItem(
        id: instance.id,
        title: reminder.title,
        scheduledTime: instance.scheduledTime.toLocal(),
        status: instance.status,
        hasVoiceNote: reminder.voiceNoteUrl != null,
        description: reminder.description,
      );
    }).toList();

    return TimelineView(
      items: timelineItems,
      onItemTap: (item) async {
        final reminder = _reminders.firstWhere(
          (r) => r.title == item.title,
          orElse: () => _reminders.first,
        );
        final result = await context.goToEditReminder(reminder.id);
        if (result == true) _loadData();
      },
    );
  }

  Widget _buildReminderTemplateCard(ReminderData reminder) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final category = CategoryInference.inferCategory(reminder.title);

    final time = '${reminder.hour.toString().padLeft(2, '0')}:${reminder.minute.toString().padLeft(2, '0')}';
    final repeatLabel = switch (reminder.repeatPattern) {
      'once' => 'Once',
      'daily' => 'Daily',
      'weekly' => 'Weekly',
      'specific_days' => 'Specific days',
      _ => reminder.repeatPattern,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AccessibleCard(
        onTap: () async {
          final result = await context.goToEditReminder(reminder.id);
          if (result == true) _loadData();
        },
        child: Row(
          children: [
            // Category icon
            CategoryIconWidget(
              category: category,
              size: 48,
              iconSize: 24,
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
                  Row(
                    children: [
                      Icon(
                        AppIcons.time,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$time • $repeatLabel',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
              AppIcons.forward,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
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
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatChip({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$value',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? color : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
