import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/redesign_tokens.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../shared/widgets/redesign_ui.dart';
import '../../../../shared/widgets/widgets.dart';
import '../widgets/add_dependent_dialog.dart';

/// Main home screen for caregivers showing their dependents
class CaregiverHomeScreen extends StatefulWidget {
  const CaregiverHomeScreen({super.key});

  @override
  State<CaregiverHomeScreen> createState() => _CaregiverHomeScreenState();
}

class _CaregiverHomeScreenState extends State<CaregiverHomeScreen>
    with WidgetsBindingObserver {
  final _userApi = getIt<UserApi>();
  final _relationshipApi = getIt<RelationshipApi>();
  final _signalRService = getIt<SignalRService>();

  UserData? _currentUser;
  List<RelationshipData> _relationships = [];
  bool _isLoading = true;

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
      debugPrint('CaregiverHomeScreen: App resumed, refreshing data');
      _loadData();
    }
  }

  void _setupConnectionStateListener() {
    _connectionStateSubscription = _signalRService.connectionState.listen((
      state,
    ) {
      debugPrint(
        'CaregiverHomeScreen: SignalR connection state changed to $state',
      );

      if (state == SignalRConnectionState.connected) {
        // Connection restored - refresh data
        debugPrint('CaregiverHomeScreen: Connection restored, refreshing data');
        _loadData();
      }
    });
  }

  void _setupSignalRListeners() {
    _signalRSubscription = _signalRService.events.listen((event) {
      debugPrint('CaregiverHomeScreen: Received SignalR event: ${event.type}');

      // Refresh on relationship changes
      if (event.type == SignalREventType.linkVerified ||
          event.type == SignalREventType.linkRequestReceived ||
          event.type == SignalREventType.linkRemoved) {
        debugPrint('CaregiverHomeScreen: Refreshing data due to ${event.type}');
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    debugPrint('CaregiverHomeScreen._loadData() called');
    setState(() => _isLoading = true);

    try {
      // Load current user from remote API
      debugPrint('Fetching current user from API...');
      _currentUser = await _userApi.getCurrentUser();
      debugPrint(
        'Current user loaded: ${_currentUser?.name}, role: ${_currentUser?.role}, uniqueCode: ${_currentUser?.uniqueCode}',
      );

      // Load relationships from remote API
      debugPrint('Fetching relationships from API...');
      final allRelationships = await _relationshipApi.getRelationships();
      // Filter to only active relationships where current user is caregiver
      _relationships = allRelationships
          .where((r) => r.isActive && r.caregiverId == _currentUser?.id)
          .toList();
      debugPrint(
        'Loaded ${_relationships.length} active relationships (dependents)',
      );
    } catch (e) {
      debugPrint('Error loading data in CaregiverHomeScreen: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: RedesignBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42.r,
                      height: 42.r,
                      decoration: BoxDecoration(
                        color: RedesignTokens.primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(21.r),
                        border: Border.all(
                          color: RedesignTokens.primary.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Icon(
                        Icons.person_2_outlined,
                        color: RedesignTokens.primary,
                        size: 24.r,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            'Hello, ${_currentUser?.name ?? 'Companion'}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => context.go(AppRoutes.settings),
                      icon: const Icon(Icons.settings_rounded),
                      tooltip: 'Settings',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? _buildSkeletonLoading()
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: _relationships.isEmpty
                            ? _buildEmptyState()
                            : _buildDependentsList(),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDependentDialog,
        backgroundColor: RedesignTokens.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        _buildUniqueCodeCard(),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Text(
            'Your Loved Ones',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        EmptyState(
          icon: Icons.people_outline,
          title: 'No Loved Ones Yet',
          message:
              'Add a loved one to start creating reminders and stay connected.',
          actionLabel: 'Add Loved One',
          onAction: _showAddDependentDialog,
        ),
      ],
    );
  }

  Widget _buildDependentsList() {
    return ListView.builder(
      padding: AppSpacing.screenPadding,
      itemCount:
          _relationships.length + 2, // +2 for unique code card and header
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildUniqueCodeCard();
        }
        if (index == 1) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Loved Ones',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${_relationships.length} Linked',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: RedesignTokens.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }

        final relationship = _relationships[index - 2];
        final dependent = relationship.dependent;
        if (dependent == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _DependentCard(
            dependent: dependent,
            onTap: () => context.goToDependentDashboard(dependent.id),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView(
      padding: AppSpacing.screenPadding,
      children: const [
        ShimmerCard(height: 124),
        SizedBox(height: AppSpacing.md),
        ShimmerCard(height: 18, width: 160),
        SizedBox(height: AppSpacing.sm),
        ShimmerCard(height: 84),
        SizedBox(height: AppSpacing.sm),
        ShimmerCard(height: 84),
        SizedBox(height: AppSpacing.sm),
        ShimmerCard(height: 84),
      ],
    );
  }

  Widget _buildUniqueCodeCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final uniqueCode = _currentUser?.uniqueCode ?? '';

    if (uniqueCode.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR CONNECTION CODE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: RedesignTokens.primary,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            uniqueCode,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Share this unique code to connect with your loved ones.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.icon(
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
                style: FilledButton.styleFrom(
                  backgroundColor: RedesignTokens.primary,
                  foregroundColor: const Color(0xFF10313A),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                icon: Icon(Icons.content_copy_rounded, size: 16.r),
                label: const Text('Copy'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddDependentDialog() {
    if (_currentUser == null) return;

    showDialog(
      context: context,
      builder: (context) => AddDependentDialog(
        caregiverId: _currentUser!.id,
        onDependentAdded: _loadData,
      ),
    );
  }
}

class _DependentCard extends StatelessWidget {
  final UserSearchResult dependent;
  final VoidCallback onTap;

  const _DependentCard({required this.dependent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AccessibleCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 56.r,
            height: 56.r,
            decoration: BoxDecoration(
              color: RedesignTokens.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(28.r),
            ),
            child: Center(
              child: Text(
                dependent.name.isNotEmpty
                    ? dependent.name[0].toUpperCase()
                    : '?',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: RedesignTokens.primary,
                  fontWeight: FontWeight.w800,
                ),
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
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Tap to view reminders',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
