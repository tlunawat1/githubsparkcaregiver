import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../shared/widgets/accessible_button.dart';
import '../widgets/voice_recorder_widget.dart';

/// Screen for adding a new reminder
class AddReminderScreen extends StatefulWidget {
  final String dependentId;

  const AddReminderScreen({
    super.key,
    required this.dependentId,
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
  String? _voiceNotePath;
  bool _isLoading = false;

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
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

    setState(() => _isLoading = true);

    try {
      // Upload voice note if present
      String? voiceNoteUrl;
      if (_voiceNotePath != null) {
        voiceNoteUrl = await _reminderApi.uploadVoiceNote(_voiceNotePath!);
      }

      String? repeatDays;
      if (_repeatPattern == 'specific_days') {
        final days = _selectedDays.map((i) => _dayNames[i].toLowerCase()).toList();
        repeatDays = days.join(',');
      }

      await _reminderApi.createReminder(
        dependentId: widget.dependentId,
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder created')),
        );
        context.pop(true); // Return true to indicate reminder was created
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
            content: Text('Error creating reminder: $e'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Reminder'),
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

            // Day selector for specific days
            if (_repeatPattern == 'specific_days') ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Select Days',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
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
              'Voice Note (optional)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            VoiceRecorderWidget(
              voiceNotePath: _voiceNotePath,
              onRecordingComplete: (path) {
                setState(() {
                  _voiceNotePath = path;
                });
              },
              onDelete: () {
                setState(() {
                  _voiceNotePath = null;
                });
              },
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Save button
            AccessibleButton(
              onPressed: _isLoading ? null : _saveReminder,
              label: 'Save Reminder',
              icon: Icons.check,
              isLoading: _isLoading,
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
