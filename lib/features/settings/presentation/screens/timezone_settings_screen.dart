import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../shared/widgets/accessible_card.dart';
import '../../../../shared/widgets/redesign_ui.dart';

/// Common timezone options for quick selection
const List<Map<String, String>> _commonTimezones = [
  {
    'id': 'America/New_York',
    'label': 'Eastern Time (US)',
    'example': 'New York',
  },
  {'id': 'America/Chicago', 'label': 'Central Time (US)', 'example': 'Chicago'},
  {'id': 'America/Denver', 'label': 'Mountain Time (US)', 'example': 'Denver'},
  {
    'id': 'America/Los_Angeles',
    'label': 'Pacific Time (US)',
    'example': 'Los Angeles',
  },
  {
    'id': 'America/Toronto',
    'label': 'Eastern Time (Canada)',
    'example': 'Toronto',
  },
  {
    'id': 'America/Vancouver',
    'label': 'Pacific Time (Canada)',
    'example': 'Vancouver',
  },
  {'id': 'Europe/London', 'label': 'Greenwich Mean Time', 'example': 'London'},
  {'id': 'Europe/Paris', 'label': 'Central European Time', 'example': 'Paris'},
  {
    'id': 'Europe/Berlin',
    'label': 'Central European Time',
    'example': 'Berlin',
  },
  {
    'id': 'Asia/Kolkata',
    'label': 'India Standard Time',
    'example': 'Mumbai, Delhi',
  },
  {'id': 'Asia/Dubai', 'label': 'Gulf Standard Time', 'example': 'Dubai'},
  {'id': 'Asia/Singapore', 'label': 'Singapore Time', 'example': 'Singapore'},
  {'id': 'Asia/Tokyo', 'label': 'Japan Standard Time', 'example': 'Tokyo'},
  {
    'id': 'Asia/Shanghai',
    'label': 'China Standard Time',
    'example': 'Shanghai, Beijing',
  },
  {'id': 'Asia/Hong_Kong', 'label': 'Hong Kong Time', 'example': 'Hong Kong'},
  {
    'id': 'Australia/Sydney',
    'label': 'Australian Eastern Time',
    'example': 'Sydney',
  },
  {
    'id': 'Australia/Melbourne',
    'label': 'Australian Eastern Time',
    'example': 'Melbourne',
  },
  {
    'id': 'Pacific/Auckland',
    'label': 'New Zealand Time',
    'example': 'Auckland',
  },
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
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  List<Map<String, String>> get _filteredTimezones {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _commonTimezones;
    }
    return _commonTimezones.where((tz) {
      final id = (tz['id'] ?? '').toLowerCase();
      final label = (tz['label'] ?? '').toLowerCase();
      final example = (tz['example'] ?? '').toLowerCase();
      return id.contains(query) ||
          label.contains(query) ||
          example.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadTimezoneData();
  }

  Future<void> _loadTimezoneData() async {
    try {
      // Get device timezone
      try {
        final tz = await FlutterTimezone.getLocalTimezone();
        _deviceTimezone = tz.identifier;
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
      Haptics.mediumImpact();

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
        body: RedesignBackground(
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      body: RedesignBackground(
        child: SafeArea(
          child: ListView(
            padding: AppSpacing.screenPadding,
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  Text(
                    'Time & Region',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              GlassCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Timezone',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentTimezone,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getTimezoneLabel(_currentTimezone) ?? 'Custom timezone',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
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
              _buildSectionHeader('Current Selection'),
              AccessibleCard(
                child: ListTile(
                  leading: Icon(Icons.schedule, color: colorScheme.primary),
                  title: Text(_currentTimezone),
                  subtitle: Text(
                    _getTimezoneLabel(_currentTimezone) ?? 'Custom timezone',
                  ),
                  trailing: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle, color: Colors.green),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Device timezone option
              if (_deviceTimezone != null &&
                  _deviceTimezone != _currentTimezone) ...[
                _buildSectionHeader('Detected Device Timezone'),
                AccessibleCard(
                  child: ListTile(
                    leading: Icon(
                      Icons.phone_android,
                      color: colorScheme.secondary,
                    ),
                    title: Text(_deviceTimezone!),
                    subtitle: Text(
                      _getTimezoneLabel(_deviceTimezone!) ?? 'Device timezone',
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: _isSaving
                          ? null
                          : () => _updateTimezone(_deviceTimezone!),
                      child: const Text('Use'),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Common timezones
              _buildSectionHeader('Select Timezone'),
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search city or region...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: colorScheme.surface.withValues(alpha: 0.72),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_filteredTimezones.isEmpty)
                AccessibleCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'No timezone matches "${_searchQuery.trim()}"',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                AccessibleCard(
                  child: Column(
                    children: _filteredTimezones.asMap().entries.map((entry) {
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
                                ? Icon(
                                    Icons.check_circle,
                                    color: colorScheme.primary,
                                  )
                                : null,
                            onTap: _isSaving
                                ? null
                                : () => _updateTimezone(tz['id']!),
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
        ),
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
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
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
