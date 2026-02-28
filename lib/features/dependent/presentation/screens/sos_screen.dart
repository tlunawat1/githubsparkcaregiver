import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../data/datasources/local/database.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../shared/widgets/redesign_ui.dart';

/// SOS emergency screen with countdown and cancellation option
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  final _sosRepository = getIt<SosRepository>();
  final _settingsRepository = getIt<SettingsRepository>();
  final _contactRepository = getIt<EmergencyContactRepository>();

  int _remainingSeconds = AppConfig.sosCancellationWindowSeconds;
  Timer? _countdownTimer;
  bool _isCancelled = false;
  bool _isCompleted = false;
  String? _sosEventId;
  List<EmergencyContact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final userId = await _settingsRepository.getCurrentUserId();
      if (userId != null) {
        _contacts = await _contactRepository.getContactsForDependent(userId);
      }
    } catch (e) {
      debugPrint('Error loading contacts: $e');
    }
    if (mounted) setState(() {});
  }

  void _startCountdown() {
    Haptics.heavyImpact();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isCancelled) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingSeconds--;
      });

      // Haptic feedback for last 3 seconds
      if (_remainingSeconds <= 3 && _remainingSeconds > 0) {
        Haptics.heavyImpact();
      }

      if (_remainingSeconds <= 0) {
        timer.cancel();
        _triggerSOS();
      }
    });
  }

  Future<void> _triggerSOS() async {
    Haptics.heavyImpact();

    try {
      final userId = await _settingsRepository.getCurrentUserId();
      if (userId == null) throw Exception('No user found');

      _sosEventId = const Uuid().v4();
      await _sosRepository.createSosEvent(
        id: _sosEventId!,
        dependentId: userId,
      );

      setState(() => _isCompleted = true);

      // In a real app, this would trigger push notifications to contacts
      // For MVP, we just show a confirmation
    } catch (e) {
      debugPrint('Error triggering SOS: $e');
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

  Future<void> _cancelSOS() async {
    Haptics.mediumImpact();
    _countdownTimer?.cancel();

    setState(() => _isCancelled = true);

    // If SOS was already triggered, cancel it in the database
    if (_sosEventId != null) {
      try {
        await _sosRepository.cancelSosEvent(_sosEventId!);
      } catch (e) {
        debugPrint('Error cancelling SOS: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS cancelled - You\'re okay!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go(AppRoutes.dependentHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isCompleted) {
      return _buildCompletedState();
    }

    return Scaffold(
      body: RedesignBackground(
        child: SafeArea(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              children: [
                IconButton.filledTonal(
                  onPressed: () {
                    _countdownTimer?.cancel();
                    context.go(AppRoutes.dependentHome);
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.emergency,
                    color: theme.colorScheme.primary,
                    size: 34,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'SOS Activated',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Remote Care Monitoring Active',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _CountdownRing(seconds: _remainingSeconds),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Emergency contacts and local response services will be notified in...',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                if (_contacts.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    alignment: WrapAlignment.center,
                    children: _contacts.take(3).map((contact) {
                      return GlassCard(
                        margin: EdgeInsets.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              contact.name,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const Spacer(),
                FilledButton.tonal(
                  onPressed: _cancelSOS,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                    foregroundColor: AppColors.error,
                    backgroundColor: AppColors.error.withValues(alpha: 0.12),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Cancel - I\'m Okay',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Hold for 2 seconds to dismiss',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Current Location: Live',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedState() {
    final theme = Theme.of(context);

    return Scaffold(
      body: RedesignBackground(
        child: SafeArea(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 64,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'SOS Sent',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Help is on the way. Stay calm and remain in a safe location.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const Spacer(),
                GradientPrimaryButton(
                  label: 'I\'m Okay - Cancel Alert',
                  icon: Icons.check_circle_outline,
                  onPressed: _cancelSOS,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => context.go(AppRoutes.dependentHome),
                  child: const Text('Return Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = AppConfig.sosCancellationWindowSeconds.toDouble();
    final progress = ((seconds / total).clamp(0.0, 1.0)).toDouble();

    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 10,
              backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.4),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$seconds',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'SECONDS',
                style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 1.6,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
