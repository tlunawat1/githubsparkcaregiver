import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../data/datasources/local/database.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../shared/widgets/accessible_button.dart';

/// SOS emergency screen with countdown and cancellation option
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  final _sosApi = getIt<SosApi>();
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
      final response = await _sosApi.triggerSos();
      _sosEventId = response.id;

      setState(() => _isCompleted = true);
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
        await _sosApi.cancelSos(_sosEventId!);
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
      backgroundColor: AppColors.errorLight,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            children: [
              // Close button row
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () {
                    _countdownTimer?.cancel();
                    context.go(AppRoutes.dependentHome);
                  },
                  icon: const Icon(Icons.close, size: 32),
                  tooltip: 'Go back',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Warning icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.error.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Colors.white,
                  size: 56,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Title
              Text(
                'SOS ACTIVATED',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              // Subtitle
              Text(
                'Emergency contacts will be notified in',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              // Countdown
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.error,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.error.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$_remainingSeconds',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Contacts to be notified
              if (_contacts.isNotEmpty) ...[
                Text(
                  'Will notify:',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _contacts.take(3).map((contact) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person,
                            size: 18,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            contact.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
              const Spacer(),
              // Cancel button
              Text(
                'If you\'re okay, tap cancel below',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AccessibleButton(
                onPressed: _cancelSOS,
                label: 'CANCEL - I\'m Okay',
                icon: Icons.check_circle,
                size: AccessibleButtonSize.xlarge,
                backgroundColor: AppColors.success,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedState() {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.errorLight,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            children: [
              // Close button row
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => context.go(AppRoutes.dependentHome),
                  icon: const Icon(Icons.close, size: 32),
                  tooltip: 'Go back',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 64,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'SOS Sent',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Your emergency contacts have been notified.',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Help is on the way. Stay calm and stay where you are if possible.',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              AccessibleButton(
                onPressed: _cancelSOS,
                label: 'I\'m Okay - Cancel Alert',
                size: AccessibleButtonSize.large,
                backgroundColor: AppColors.success,
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => context.go(AppRoutes.dependentHome),
                child: Text(
                  'Return Home',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
