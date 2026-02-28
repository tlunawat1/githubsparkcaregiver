import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/custom_icons.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/redesign_tokens.dart';
import '../../../../core/utils/animation_settings.dart';
import '../../../../core/utils/category_inference.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../data/datasources/local/database.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../shared/widgets/redesign_ui.dart';
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
  final _careRelationshipRepository = getIt<CareRelationshipRepository>();
  final _signalRService = getIt<SignalRService>();
  final _settingsRepository = getIt<SettingsRepository>();

  UserData? _user;
  List<ReminderData> _reminders = [];
  List<ReminderInstanceData> _todayInstances = [];
  List<CareRelationship> _pendingLinks = [];
  Map<String, User> _pendingLinkCaregivers = {};
  bool _isLoading = true;
  bool _isInitialLoad = true;
  final Set<String> _completingInstances = {};
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
    debugPrint('DependentHomeScreen: Starting screen initialization');

    // Pre-load animation settings for synchronous access
    await _settingsRepository.isReduceAnimationsEnabled();

    // 1. Set up connection state listener first (to handle reconnections)
    _setupConnectionStateListener();

    // 2. Ensure SignalR is connected (silent background connection with retry)
    await _ensureSignalRConnected();

    // 3. Set up event listeners (now guaranteed to receive events)
    _setupSignalRListeners();
    _isSignalRInitialized = true;
    debugPrint('DependentHomeScreen: SignalR initialization complete');

    // 4. Load data (fresh data + real-time updates ready)
    _loadData();
  }

  /// Ensure SignalR is connected with automatic retry
  Future<void> _ensureSignalRConnected() async {
    debugPrint('DependentHomeScreen: Ensuring SignalR connection...');
    debugPrint(
      'DependentHomeScreen: Current SignalR state: ${_signalRService.currentState}',
    );

    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      final connected = await _signalRService.ensureConnected();

      if (connected) {
        debugPrint(
          'DependentHomeScreen: SignalR connected successfully on attempt $attempt',
        );
        return;
      }

      debugPrint(
        'DependentHomeScreen: SignalR connection attempt $attempt/$maxRetries failed',
      );

      if (attempt < maxRetries) {
        debugPrint(
          'DependentHomeScreen: Retrying in ${retryDelay.inSeconds} seconds...',
        );
        await Future.delayed(retryDelay);
      }
    }

    debugPrint(
      'DependentHomeScreen: SignalR connection failed after $maxRetries attempts, continuing without real-time updates',
    );
    // Continue anyway - user can still use pull-to-refresh
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
    debugPrint('DependentHomeScreen: App lifecycle state changed to $state');

    if (state == AppLifecycleState.resumed) {
      debugPrint('DependentHomeScreen: App resumed from background');
      debugPrint(
        'DependentHomeScreen: Current SignalR state: ${_signalRService.currentState}',
      );

      // Ensure SignalR is connected after resume (in background)
      _ensureSignalRConnected().then((_) {
        debugPrint(
          'DependentHomeScreen: SignalR check complete after resume, refreshing data',
        );
        _loadData();
      });
    } else if (state == AppLifecycleState.paused) {
      debugPrint('DependentHomeScreen: App going to background');
    }
  }

  void _setupConnectionStateListener() {
    debugPrint('DependentHomeScreen: Setting up connection state listener');
    _connectionStateSubscription = _signalRService.connectionState.listen((
      state,
    ) {
      debugPrint(
        'DependentHomeScreen: SignalR connection state changed: $state',
      );

      if (state == SignalRConnectionState.connected) {
        // Connection restored - refresh data to get any updates we missed
        debugPrint(
          'DependentHomeScreen: Connection restored, refreshing data to sync missed updates',
        );
        _loadData();

        // If SignalR wasn't initialized yet, set up listeners now
        if (!_isSignalRInitialized) {
          debugPrint(
            'DependentHomeScreen: Late initialization - setting up SignalR listeners after reconnection',
          );
          _setupSignalRListeners();
          _isSignalRInitialized = true;
        }
      } else if (state == SignalRConnectionState.disconnected) {
        debugPrint(
          'DependentHomeScreen: SignalR disconnected - real-time updates paused',
        );
      } else if (state == SignalRConnectionState.reconnecting) {
        debugPrint('DependentHomeScreen: SignalR reconnecting...');
      }
    });
  }

  void _setupSignalRListeners() {
    // Avoid duplicate subscriptions
    if (_signalRSubscription != null) {
      debugPrint(
        'DependentHomeScreen: SignalR event listener already set up, skipping',
      );
      return;
    }

    debugPrint('DependentHomeScreen: Setting up SignalR event listeners');
    debugPrint(
      'DependentHomeScreen: SignalR isConnected=${_signalRService.isConnected}, state=${_signalRService.currentState}',
    );

    _signalRSubscription = _signalRService.events.listen((event) {
      debugPrint(
        'DependentHomeScreen: ========== SignalR EVENT RECEIVED ==========',
      );
      debugPrint('DependentHomeScreen: Event type: ${event.type}');
      debugPrint('DependentHomeScreen: Event data: ${event.data}');
      debugPrint('DependentHomeScreen: Event timestamp: ${event.timestamp}');
      debugPrint(
        'DependentHomeScreen: ============================================',
      );

      if (event.type == SignalREventType.instanceCreated ||
          event.type == SignalREventType.instanceStatusChanged ||
          event.type == SignalREventType.reminderCreated ||
          event.type == SignalREventType.reminderUpdated ||
          event.type == SignalREventType.reminderDeleted ||
          event.type == SignalREventType.linkVerified ||
          event.type == SignalREventType.linkRequestReceived) {
        debugPrint(
          'DependentHomeScreen: Event matched! Triggering data refresh for ${event.type}',
        );
        _loadData();
      } else {
        debugPrint(
          'DependentHomeScreen: Event ${event.type} not handled by this screen',
        );
      }
    });

    debugPrint(
      'DependentHomeScreen: SignalR event listener registered successfully',
    );
  }

  Future<void> _loadData() async {
    debugPrint('DependentHomeScreen: _loadData() called');
    debugPrint(
      'DependentHomeScreen: isInitialLoad=$_isInitialLoad, SignalR state=${_signalRService.currentState}',
    );

    // Only show loading indicator on initial load to avoid jarring screen flashes
    if (_isInitialLoad) {
      setState(() => _isLoading = true);
    }

    try {
      // Load current user from remote API
      _user = await _userApi.getCurrentUser();
      debugPrint('DependentHomeScreen: User loaded: ${_user?.id}');

      if (_user != null) {
        final userId = _user!.id;
        _reminders = await _reminderApi.getReminders(dependentId: userId);
        debugPrint(
          'DependentHomeScreen: Loaded ${_reminders.length} reminders',
        );

        _todayInstances = await _reminderInstanceApi.getInstances(
          dependentId: userId,
          date: DateTime.now(),
        );
        debugPrint(
          'DependentHomeScreen: Loaded ${_todayInstances.length} instances for today',
        );

        // Log instance statuses for debugging
        final statusCounts = <String, int>{};
        for (final instance in _todayInstances) {
          statusCounts[instance.status] =
              (statusCounts[instance.status] ?? 0) + 1;
        }
        debugPrint('DependentHomeScreen: Instance statuses: $statusCounts');

        // Load pending link requests
        _pendingLinks = await _careRelationshipRepository
            .getPendingLinksForDependent(userId);
        debugPrint(
          'DependentHomeScreen: Loaded ${_pendingLinks.length} pending links',
        );

        // Load caregiver info for each pending link
        _pendingLinkCaregivers = {};
        for (final link in _pendingLinks) {
          final caregiver = await _userRepository.getUserById(link.caregiverId);
          if (caregiver != null) {
            _pendingLinkCaregivers[link.id] = caregiver;
          }
        }
      }

      debugPrint('DependentHomeScreen: Data load completed successfully');
    } catch (e) {
      debugPrint('DependentHomeScreen: Error loading data: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isInitialLoad = false;
      });
      debugPrint('DependentHomeScreen: UI state updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);

    return Scaffold(
      body: RedesignBackground(
        child: SafeArea(
          child: _isLoading
              ? _buildSkeletonLoading()
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '$greeting, ${_user?.name ?? 'Friend'}',
                                          style: theme.textTheme.headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      IconButton.filledTonal(
                                        icon: const Icon(
                                          Icons.settings,
                                          size: 22,
                                        ),
                                        onPressed: () =>
                                            context.go(AppRoutes.settings),
                                        tooltip: 'Settings',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    DateFormat('EEEE, MMMM d').format(now),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
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
                                        onTap: () => _showLinkRequestDialog(
                                          link,
                                          caregiver,
                                        ),
                                      );
                                    }),
                                  ],
                                  // Today's Progress section
                                  if (_todayInstances.isNotEmpty) ...[
                                    const SizedBox(height: AppSpacing.lg),
                                    _buildTodaysProgress(),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          // Coming up reminders
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                AppSpacing.lg,
                                AppSpacing.md,
                                AppSpacing.sm,
                              ),
                              child: Text(
                                'Coming Up Today',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
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
                          else ...[
                            // "Up Next" hero card for first pending reminder
                            if (_getNextPendingReminder() != null)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: AppSpacing.screenPaddingHorizontal,
                                  child: _buildUpNextCard(),
                                ),
                              ),

                            // Remaining reminders in 2-column grid with staggered animations
                            SliverPadding(
                              padding: AppSpacing.screenPaddingHorizontal,
                              sliver: SliverGrid(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: AppSpacing.md,
                                      crossAxisSpacing: AppSpacing.md,
                                      childAspectRatio: 1.55,
                                    ),
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final otherReminders = _getOtherReminders();
                                  if (index >= otherReminders.length) {
                                    return null;
                                  }

                                  final instance = otherReminders[index];
                                  final reminder = _reminders
                                      .cast<ReminderData?>()
                                      .firstWhere(
                                        (r) => r?.id == instance.reminderId,
                                        orElse: () => null,
                                      );

                                  // For pending instances, use reminder template time (hour/minute are in local time)
                                  // For completed/missed instances, convert UTC scheduledTime to local time
                                  final localScheduledTime = instance
                                      .scheduledTime
                                      .toLocal();
                                  final displayTime =
                                      instance.status == 'pending' &&
                                          reminder != null
                                      ? DateTime(
                                          localScheduledTime.year,
                                          localScheduledTime.month,
                                          localScheduledTime.day,
                                          reminder.hour,
                                          reminder.minute,
                                        )
                                      : localScheduledTime;

                                  final card = _buildComingUpCard(
                                    instance: instance,
                                    reminder: reminder,
                                    displayTime: displayTime,
                                  );

                                  // Apply staggered animation if animations are enabled
                                  if (AnimationSettings.shouldAnimate(
                                    context,
                                  )) {
                                    return card
                                        .animate()
                                        .fadeIn(
                                          duration: 200.ms,
                                          delay: (index * 50).ms,
                                        )
                                        .slideY(
                                          begin: 0.1,
                                          end: 0,
                                          duration: 200.ms,
                                          delay: (index * 50).ms,
                                          curve: Curves.easeOut,
                                        );
                                  }
                                  return card;
                                }, childCount: _getOtherReminders().length),
                              ),
                            ),
                          ],

                          // Spacer for SOS button (increased to prevent overflow)
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 150),
                          ),
                        ],
                      ),
                    ),
                    // SOS button fixed at bottom (further reduced - 25% smaller)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SafeArea(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withValues(alpha: 0.9),
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
                              size: 56,
                              width: double.infinity,
                              onActivated: () {
                                context.go('${AppRoutes.dependentHome}/sos');
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
    Haptics.mediumImpact();

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
    Haptics.lightImpact();

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

  void _showDetailsModal(
    ReminderInstanceData instance,
    ReminderData? reminder,
  ) {
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

  Widget _buildComingUpCard({
    required ReminderInstanceData instance,
    required ReminderData? reminder,
    required DateTime displayTime,
  }) {
    final theme = Theme.of(context);
    final title = reminder?.title ?? instance.reminderTitle ?? 'Reminder';
    final category = CategoryInference.inferCategory(title);
    final icon = AppIcons.getCategoryIcon(category);
    final iconColor = AppIcons.getCategoryColor(category);
    final isLoading = _completingInstances.contains(instance.id);
    final statusLabel = switch (instance.status) {
      'completed' => 'Done',
      'missed' => 'Missed',
      'pending' => 'Tap to complete',
      'snoozed' => 'Snoozed',
      _ => 'Upcoming',
    };
    final statusBg = switch (instance.status) {
      'completed' => Colors.green.withValues(alpha: 0.14),
      'missed' => Colors.redAccent.withValues(alpha: 0.14),
      'pending' => theme.colorScheme.primary.withValues(alpha: 0.14),
      'snoozed' => Colors.orange.withValues(alpha: 0.14),
      _ => theme.colorScheme.surfaceContainerHighest,
    };
    final statusFg = switch (instance.status) {
      'completed' => Colors.green,
      'missed' => Colors.redAccent,
      'pending' => theme.colorScheme.primary,
      'snoozed' => Colors.orange,
      _ => theme.colorScheme.onSurfaceVariant,
    };

    return GestureDetector(
      onTap: () => _markInstanceComplete(instance.id),
      onLongPress: () => _showDetailsModal(instance, reminder),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                Text(
                  DateFormat.jm().format(displayTime),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(99),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: statusFg,
                      ),
                    )
                  : Text(
                      statusLabel.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusFg,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
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
            child: const Icon(Icons.check, color: Colors.white, size: 48),
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
    final uniqueCode = _user?.uniqueCode ?? '';

    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(Icons.qr_code, color: RedesignTokens.primary, size: 24),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Your Code:',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              uniqueCode,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: RedesignTokens.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: uniqueCode));
              Haptics.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Code copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Copy code',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  /// Get the first pending reminder for the "Up Next" hero card
  ReminderInstanceData? _getNextPendingReminder() {
    final sorted = _getSortedReminders();
    try {
      return sorted.firstWhere(
        (r) => r.status == 'pending' || r.status == 'snoozed',
      );
    } catch (_) {
      return null;
    }
  }

  /// Get all reminders except the first pending one (for the grid)
  List<ReminderInstanceData> _getOtherReminders() {
    final sorted = _getSortedReminders();
    final nextPending = _getNextPendingReminder();
    if (nextPending == null) return sorted;
    return sorted.where((r) => r.id != nextPending.id).toList();
  }

  /// Build the "Up Next" hero card for the first pending reminder (reduced height)
  Widget _buildUpNextCard() {
    final theme = Theme.of(context);
    final nextReminder = _getNextPendingReminder();
    if (nextReminder == null) return const SizedBox.shrink();

    final reminder = _reminders.cast<ReminderData?>().firstWhere(
      (r) => r?.id == nextReminder.reminderId,
      orElse: () => null,
    );

    final title = reminder?.title ?? nextReminder.reminderTitle ?? 'Reminder';
    final category = CategoryInference.inferCategory(title);
    final categoryColor = AppIcons.getCategoryColor(category);
    final categoryIcon = AppIcons.getCategoryIcon(category);

    final localScheduledTime = nextReminder.scheduledTime.toLocal();
    final displayTime = nextReminder.status == 'pending' && reminder != null
        ? DateTime(
            localScheduledTime.year,
            localScheduledTime.month,
            localScheduledTime.day,
            reminder.hour,
            reminder.minute,
          )
        : localScheduledTime;

    final isLoading = _completingInstances.contains(nextReminder.id);

    Widget card = Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'UP NEXT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat.jm().format(displayTime),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(categoryIcon, color: categoryColor, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => _markInstanceComplete(nextReminder.id),
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(isLoading ? 'Completing...' : 'Mark as Done'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filledTonal(
                onPressed: () => _showDetailsModal(nextReminder, reminder),
                icon: const Icon(Icons.info_outline),
              ),
            ],
          ),
        ],
      ),
    );

    if (AnimationSettings.shouldAnimate(context)) {
      card = card.animate().fadeIn(duration: 220.ms);
    }

    return card;
  }

  /// Build Today's Progress section - same as caregiver dashboard
  Widget _buildTodaysProgress() {
    final total = _todayInstances.length;
    final completed = _todayInstances
        .where((i) => i.status == 'completed')
        .length;
    final ratio = total == 0 ? 0.0 : completed / total;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Progress',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '$completed of $total tasks done',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: ratio.clamp(0.0, 1.0),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }

  /// Build skeleton loading state
  Widget _buildSkeletonLoading() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);

    return CustomScrollView(
      slivers: [
        // Header (same as real content)
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
                          // Skeleton for name
                          Container(
                            width: 150,
                            height: 32,
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.settings, size: 28),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  DateFormat('EEEE, MMMM d').format(now),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Today's reminders header
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

        // Skeleton grid
        SliverPadding(
          padding: AppSpacing.screenPaddingHorizontal,
          sliver: SliverToBoxAdapter(
            child: const ReminderSkeletonGrid(itemCount: 4),
          ),
        ),

        // Spacer for SOS button
        const SliverToBoxAdapter(child: SizedBox(height: 200)),
      ],
    );
  }
}
