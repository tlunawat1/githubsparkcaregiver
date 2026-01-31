import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../shared/widgets/accessible_button.dart';
import '../widgets/voice_recorder_widget.dart';

/// Screen for editing an existing reminder
class EditReminderScreen extends StatefulWidget {
  final String reminderId;

  const EditReminderScreen({
    super.key,
    required this.reminderId,
  });

  @override
  State<EditReminderScreen> createState() => _EditReminderScreenState();
}

class _EditReminderScreenState extends State<EditReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _reminderApi = getIt<ReminderApi>();

  ReminderData? _reminder;
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _repeatPattern = 'daily';
  Set<int> _selectedDays = {};
  String _priority = 'normal';
  String? _voiceNotePath; // Local path for new recordings
  String? _voiceNoteUrl; // Remote URL for existing recordings
  bool _isLoading = true;
  bool _isSaving = false;

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
    _loadReminder();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadReminder() async {
    try {
      _reminder = await _reminderApi.getReminder(widget.reminderId);

      if (_reminder != null) {
        _titleController.text = _reminder!.title;
        _descriptionController.text = _reminder!.description ?? '';
        _selectedTime = TimeOfDay(hour: _reminder!.hour, minute: _reminder!.minute);
        _repeatPattern = _reminder!.repeatPattern;
        _priority = _reminder!.priority;
        _voiceNoteUrl = _reminder!.voiceNoteUrl;

        // Parse selected days
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
      }
    } on ApiException catch (e) {
      debugPrint('Error loading reminder: ${e.message}');
    } catch (e) {
      debugPrint('Error loading reminder: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
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
      // Upload new voice note if a local path is set
      String? newVoiceNoteUrl = _voiceNoteUrl;
      if (_voiceNotePath != null) {
        newVoiceNoteUrl = await _reminderApi.uploadVoiceNote(_voiceNotePath!);
      }

      String? repeatDays;
      if (_repeatPattern == 'specific_days') {
        final days = _selectedDays.map((i) => _dayNames[i].toLowerCase()).toList();
        repeatDays = days.join(',');
      }

      await _reminderApi.updateReminder(
        id: widget.reminderId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        voiceNoteUrl: newVoiceNoteUrl,
        repeatPattern: _repeatPattern,
        repeatDays: repeatDays,
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
        priority: _priority,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder updated')),
        );
        context.pop(true); // Return true to indicate reminder was modified
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
            content: Text('Error updating reminder: $e'),
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
        await _reminderApi.deleteReminder(widget.reminderId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reminder deleted')),
          );
          context.pop(true); // Return true to indicate reminder was modified
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
        appBar: AppBar(title: const Text('Edit Reminder')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_reminder == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Reminder')),
        body: const Center(child: Text('Reminder not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Reminder'),
        actions: [
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

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
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
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outline),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: colorScheme.primary),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      _selectedTime.format(context),
                      style: theme.textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    Icon(Icons.edit, color: colorScheme.onSurfaceVariant),
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
              spacing: AppSpacing.sm,
              children: _repeatOptions.map((option) {
                final isSelected = _repeatPattern == option;
                return ChoiceChip(
                  label: Text(_repeatLabels[option]!),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _repeatPattern = option;
                      });
                    }
                  },
                );
              }).toList(),
            ),

            // Day selector
            if (_repeatPattern == 'specific_days') ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                children: List.generate(7, (index) {
                  final isSelected = _selectedDays.contains(index);
                  return FilterChip(
                    label: Text(_dayNames[index]),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedDays.add(index);
                        } else {
                          _selectedDays.remove(index);
                        }
                      });
                    },
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
              'Voice Note',
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
                  _voiceNoteUrl = null; // Clear URL when new recording is made
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
              label: 'Save Changes',
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
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : null,
          border: Border.all(
            color: isSelected ? color : theme.colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
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
