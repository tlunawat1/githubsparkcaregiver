import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../data/datasources/remote/remote.dart';
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
    _connectionStateSubscription = _signalRService.connectionState.listen((state) {
      debugPrint('CaregiverHomeScreen: SignalR connection state changed to $state');
      
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
      debugPrint('Current user loaded: ${_currentUser?.name}, role: ${_currentUser?.role}, uniqueCode: ${_currentUser?.uniqueCode}');

      // Load relationships from remote API
      debugPrint('Fetching relationships from API...');
      final allRelationships = await _relationshipApi.getRelationships();
      // Filter to only active relationships where current user is caregiver
      _relationships = allRelationships
          .where((r) => r.isActive && r.caregiverId == _currentUser?.id)
          .toList();
      debugPrint('Loaded ${_relationships.length} active relationships (dependents)');
    } catch (e) {
      debugPrint('Error loading data in CaregiverHomeScreen: $e');
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
            onPressed: () => context.go(AppRoutes.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator(message: 'Loading...')
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _relationships.isEmpty
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
    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        _buildUniqueCodeCard(),
        EmptyState(
          icon: Icons.people_outline,
          title: 'No Dependents Yet',
          message: 'Add a dependent to start creating reminders and stay connected.',
          actionLabel: 'Add Dependent',
          onAction: _showAddDependentDialog,
        ),
      ],
    );
  }

  Widget _buildDependentsList() {
    return ListView.builder(
      padding: AppSpacing.screenPadding,
      itemCount: _relationships.length + 2, // +2 for unique code card and header
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildUniqueCodeCard();
        }
        if (index == 1) {
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

        final relationship = _relationships[index - 2];
        final dependent = relationship.dependent;
        if (dependent == null) return const SizedBox.shrink();

        return _DependentCard(
          dependent: dependent,
          onTap: () => context.goToDependentDashboard(dependent.id),
        );
      },
    );
  }

  Widget _buildUniqueCodeCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final uniqueCode = _currentUser?.uniqueCode ?? '';

    if (uniqueCode.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.qr_code, color: colorScheme.primary, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Code',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  uniqueCode,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy),
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
