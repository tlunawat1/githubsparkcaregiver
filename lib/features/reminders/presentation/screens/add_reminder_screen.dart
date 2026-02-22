import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_config.dart';
import '../../../../core/di/injection.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../domain/notification_service.dart';
import '../../../../shared/widgets/accessible_button.dart';
import '../widgets/voice_recorder_widget.dart';

/// Unified reminder form screen for add/edit.
class AddReminderScreen extends StatefulWidget {
  final String? dependentId;
  final String? reminderId;

  const AddReminderScreen({
    super.key,
    this.dependentId,
    this.reminderId,
  });

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _reminderApi = getIt<ReminderApi>();

  TimeOfDay _selectedTime = TimeOfDay.now();
  String _repeatPattern = 'daily';
  Set<int> _selectedDays = {};
  String _priority = 'normal';
  String? _voiceNotePath; // local path for new recordings
  String? _voiceNoteUrl; // remote url for existing recording
  ReminderData? _reminder;
  bool _isLoading = false;
  bool _isSaving = false;

  bool get _isEdit => widget.reminderId != null;

  int _notificationIdForReminder(String reminderId) {
    // Keep IDs stable across app restarts so edits can cancel/reschedule.
    return (reminderId.hashCode & 0x7fffffff) % 100000;
  }

  DateTime _nextScheduledTime({
    required int hour,
    required int minute,
    required String repeatPattern,
    required Set<int> selectedDays,
  }) {
    final now = DateTime.now();
    var candidate = DateTime(now.year, now.month, now.day, hour, minute);

    // If time already passed for today, start checking from tomorrow.
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }

    if (repeatPattern == 'weekly') {
      // Weekly: same weekday next week if today's window passed.
      final daysUntilNextWeek = 7 - (now.weekday - 1);
      // If we already rolled to tomorrow above, keep candidate as-is.
      if (candidate.difference(now).inDays == 0) {
        candidate = candidate.add(Duration(days: daysUntilNextWeek));
      }
    }

    if (repeatPattern == 'specific_days') {
      // selectedDays are indices 0..6 for Mon..Sun.
      if (selectedDays.isEmpty) return candidate;
      for (var i = 0; i < 14; i++) {
        final day = candidate.add(Duration(days: i));
        final idx = day.weekday - 1;
        if (selectedDays.contains(idx)) {
          return DateTime(day.year, day.month, day.day, hour, minute);
        }
      }
    }

    return candidate;
  }

  final List<String> _repeatOptions = [
    'once',
    'daily',
    'weekly',
    'specific_days',
  ];

  final Map<String, String> _repeatLabels = {
    'once': 'Once',
    'daily': 'Daily',
    'weekly': 'Weekly',
    'specific_days': 'Specific Days',
  };

  final List<String> _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadReminder();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadReminder() async {
    setState(() => _isLoading = true);
    try {
      _reminder = await _reminderApi.getReminder(widget.reminderId!);
      _titleController.text = _reminder!.title;
      _descriptionController.text = _reminder!.description ?? '';
      _selectedTime = TimeOfDay(hour: _reminder!.hour, minute: _reminder!.minute);
      _repeatPattern = _reminder!.repeatPattern;
      _priority = _reminder!.priority;
      _voiceNoteUrl = _reminder!.voiceNoteUrl;
      _selectedDays.clear();
      if (_reminder!.repeatDays != null) {
        final days = _reminder!.repeatDays!.split(',');
        for (final day in days) {
          final index = _dayNames.indexWhere(
            (d) => d.toLowerCase() == day.trim().toLowerCase(),
          );
          if (index >= 0) {
            _selectedDays.add(index);
          }
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading reminder: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_repeatPattern == 'specific_days' && _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? voiceNoteUrl = _voiceNoteUrl;
      if (_voiceNotePath != null) {
        voiceNoteUrl = await _reminderApi.uploadVoiceNote(_voiceNotePath!);
      }

      String? repeatDays;
      if (_repeatPattern == 'specific_days') {
        final days = _selectedDays.map((i) => _dayNames[i].toLowerCase()).toList();
        repeatDays = days.join(',');
      }

      if (_isEdit) {
        final updated = await _reminderApi.updateReminder(
          id: widget.reminderId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          voiceNoteUrl: voiceNoteUrl,
          repeatPattern: _repeatPattern,
          repeatDays: repeatDays,
          hour: _selectedTime.hour,
          minute: _selectedTime.minute,
          priority: _priority,
        );

        if (!AppConfig.enablePushNotifications) {
          final notificationId = _notificationIdForReminder(updated.id);
          await NotificationService().cancelNotification(notificationId);
          final scheduledTime = _nextScheduledTime(
            hour: updated.hour,
            minute: updated.minute,
            repeatPattern: updated.repeatPattern,
            selectedDays: _selectedDays,
          );
          await NotificationService().scheduleReminderNotification(
            id: notificationId,
            title: updated.title,
            body: (updated.description ?? '').isEmpty ? 'Reminder due now' : updated.description!,
            scheduledTime: scheduledTime,
            payload: '{"type":"reminder","reminderId":"${updated.id}"}',
            isHighPriority: updated.priority.toLowerCase() != 'normal',
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reminder updated')),
          );
          context.pop(true);
        }
      } else {
        final dependentId = widget.dependentId;
        if (dependentId == null || dependentId.isEmpty) {
          throw Exception('Dependent ID is required for creating reminders');
        }

        final created = await _reminderApi.createReminder(
          dependentId: dependentId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          voiceNoteUrl: voiceNoteUrl,
          repeatPattern: _repeatPattern,
          repeatDays: repeatDays,
          hour: _selectedTime.hour,
          minute: _selectedTime.minute,
          priority: _priority,
          startDate: DateTime.now(),
        );

        if (!AppConfig.enablePushNotifications) {
          final scheduledTime = _nextScheduledTime(
            hour: created.hour,
            minute: created.minute,
            repeatPattern: created.repeatPattern,
            selectedDays: _selectedDays,
          );
          await NotificationService().scheduleReminderNotification(
            id: _notificationIdForReminder(created.id),
            title: created.title,
            body: (created.description ?? '').isEmpty ? 'Reminder due now' : created.description!,
            scheduledTime: scheduledTime,
            payload: '{"type":"reminder","reminderId":"${created.id}"}',
            isHighPriority: created.priority.toLowerCase() != 'normal',
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reminder created')),
          );
          context.pop(true);
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving reminder: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteReminder() async {
    if (!_isEdit) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: const Text('Are you sure you want to delete this reminder?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (!AppConfig.enablePushNotifications) {
          await NotificationService().cancelNotification(
            _notificationIdForReminder(widget.reminderId!),
          );
        }
        await _reminderApi.deleteReminder(widget.reminderId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reminder deleted')),
          );
          context.pop(true);
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.message}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting reminder: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(_isEdit ? 'Edit Reminder' : 'Add Reminder')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_isEdit && _reminder == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Reminder')),
        body: const Center(child: Text('Reminder not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Reminder' : 'Add Reminder'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: Icon(Icons.delete, color: colorScheme.error),
              onPressed: _deleteReminder,
              tooltip: 'Delete',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g., Take medication',
                prefixIcon: Icon(Icons.title),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Description (optional)
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Additional details...',
                prefixIcon: Icon(Icons.notes),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Time picker
            Text(
              'Time',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: _selectTime,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outline),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: colorScheme.primary, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      _selectedTime.format(context),
                      style: theme.textTheme.titleLarge,
                    ),
                    const Spacer(),
                    Icon(Icons.edit, color: colorScheme.onSurfaceVariant, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Repeat pattern
            Text(
              'Repeat',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              children: _repeatOptions.map((option) {
                final isSelected = _repeatPattern == option;
                return GestureDetector(
                  onTap: () => setState(() => _repeatPattern = option),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      _repeatLabels[option]!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // Day selector for specific days
            if (_repeatPattern == 'specific_days') ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Select Days',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (index) {
                  final isSelected = _selectedDays.contains(index);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedDays.remove(index);
                        } else {
                          _selectedDays.add(index);
                        }
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Center(
                        child: Text(
                          _dayNames[index],
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            // Priority
            Text(
              'Priority',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _PriorityOption(
                    label: 'Normal',
                    isSelected: _priority == 'normal',
                    color: colorScheme.primary,
                    onTap: () => setState(() => _priority = 'normal'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _PriorityOption(
                    label: 'High',
                    isSelected: _priority == 'high',
                    color: colorScheme.error,
                    onTap: () => setState(() => _priority = 'high'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Voice note
            Text(
              'Voice Note (optional)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            VoiceRecorderWidget(
              voiceNotePath: _voiceNotePath,
              voiceNoteUrl: _voiceNoteUrl,
              onRecordingComplete: (path) {
                setState(() {
                  _voiceNotePath = path;
                  _voiceNoteUrl = null;
                });
              },
              onDelete: () {
                setState(() {
                  _voiceNotePath = null;
                  _voiceNoteUrl = null;
                });
              },
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Save button
            AccessibleButton(
              onPressed: _isSaving ? null : _saveReminder,
              label: _isEdit ? 'Save Changes' : 'Save Reminder',
              icon: Icons.check,
              isLoading: _isSaving,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _PriorityOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _PriorityOption({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : null,
          border: Border.all(
            color: isSelected ? color : theme.colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected ? color : null,
                fontWeight: isSelected ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
