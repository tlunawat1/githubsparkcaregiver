import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../shared/widgets/accessible_card.dart';

/// Common timezone options for quick selection
const List<Map<String, String>> _commonTimezones = [
  {'id': 'America/New_York', 'label': 'Eastern Time (US)', 'example': 'New York'},
  {'id': 'America/Chicago', 'label': 'Central Time (US)', 'example': 'Chicago'},
  {'id': 'America/Denver', 'label': 'Mountain Time (US)', 'example': 'Denver'},
  {'id': 'America/Los_Angeles', 'label': 'Pacific Time (US)', 'example': 'Los Angeles'},
  {'id': 'America/Toronto', 'label': 'Eastern Time (Canada)', 'example': 'Toronto'},
  {'id': 'America/Vancouver', 'label': 'Pacific Time (Canada)', 'example': 'Vancouver'},
  {'id': 'Europe/London', 'label': 'Greenwich Mean Time', 'example': 'London'},
  {'id': 'Europe/Paris', 'label': 'Central European Time', 'example': 'Paris'},
  {'id': 'Europe/Berlin', 'label': 'Central European Time', 'example': 'Berlin'},
  {'id': 'Asia/Kolkata', 'label': 'India Standard Time', 'example': 'Mumbai, Delhi'},
  {'id': 'Asia/Dubai', 'label': 'Gulf Standard Time', 'example': 'Dubai'},
  {'id': 'Asia/Singapore', 'label': 'Singapore Time', 'example': 'Singapore'},
  {'id': 'Asia/Tokyo', 'label': 'Japan Standard Time', 'example': 'Tokyo'},
  {'id': 'Asia/Shanghai', 'label': 'China Standard Time', 'example': 'Shanghai, Beijing'},
  {'id': 'Asia/Hong_Kong', 'label': 'Hong Kong Time', 'example': 'Hong Kong'},
  {'id': 'Australia/Sydney', 'label': 'Australian Eastern Time', 'example': 'Sydney'},
  {'id': 'Australia/Melbourne', 'label': 'Australian Eastern Time', 'example': 'Melbourne'},
  {'id': 'Pacific/Auckland', 'label': 'New Zealand Time', 'example': 'Auckland'},
];

/// Screen for managing timezone settings
class TimezoneSettingsScreen extends StatefulWidget {
  const TimezoneSettingsScreen({super.key});

  @override
  State<TimezoneSettingsScreen> createState() => _TimezoneSettingsScreenState();
}

class _TimezoneSettingsScreenState extends State<TimezoneSettingsScreen> {
  final _userApi = getIt<UserApi>();

  String _currentTimezone = 'UTC';
  String? _deviceTimezone;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTimezoneData();
  }

  Future<void> _loadTimezoneData() async {
    try {
      // Get device timezone
      try {
        _deviceTimezone = await FlutterTimezone.getLocalTimezone();
      } catch (e) {
        debugPrint('Could not detect device timezone: $e');
      }

      // Get current user timezone from API
      final user = await _userApi.getCurrentUser();
      _currentTimezone = user.timezone;
    } catch (e) {
      _errorMessage = 'Failed to load timezone settings';
      debugPrint('Error loading timezone: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateTimezone(String timezone) async {
    if (timezone == _currentTimezone) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _userApi.updateTimezone(timezone);
      HapticFeedback.mediumImpact();

      setState(() {
        _currentTimezone = timezone;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timezone updated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update timezone';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Timezone')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Timezone'),
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          // Error message
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: colorScheme.error),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Current timezone info
          _buildSectionHeader('Current Timezone'),
          AccessibleCard(
            child: ListTile(
              leading: Icon(Icons.schedule, color: colorScheme.primary),
              title: Text(
                _currentTimezone,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                _getTimezoneLabel(_currentTimezone) ?? 'Custom timezone',
              ),
              trailing: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Device timezone option
          if (_deviceTimezone != null && _deviceTimezone != _currentTimezone) ...[
            _buildSectionHeader('Detected Device Timezone'),
            AccessibleCard(
              child: ListTile(
                leading: Icon(Icons.phone_android, color: colorScheme.secondary),
                title: Text(_deviceTimezone!),
                subtitle: Text(_getTimezoneLabel(_deviceTimezone!) ?? 'Device timezone'),
                trailing: FilledButton.tonal(
                  onPressed: _isSaving ? null : () => _updateTimezone(_deviceTimezone!),
                  child: const Text('Use'),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Common timezones
          _buildSectionHeader('Select Timezone'),
          AccessibleCard(
            child: Column(
              children: _commonTimezones.asMap().entries.map((entry) {
                final index = entry.key;
                final tz = entry.value;
                final isSelected = tz['id'] == _currentTimezone;

                return Column(
                  children: [
                    if (index > 0) const Divider(height: 1),
                    ListTile(
                      title: Text(tz['label']!),
                      subtitle: Text(tz['example']!),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: colorScheme.primary)
                          : null,
                      onTap: _isSaving ? null : () => _updateTimezone(tz['id']!),
                      selected: isSelected,
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Info text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              'Your timezone is used to schedule reminders at the correct time. '
              'When you change your timezone, all pending reminders will be '
              'automatically adjusted.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String? _getTimezoneLabel(String timezoneId) {
    for (final tz in _commonTimezones) {
      if (tz['id'] == timezoneId) {
        return tz['label'];
      }
    }
    return null;
  }
}
