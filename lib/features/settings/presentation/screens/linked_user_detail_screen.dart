import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../shared/widgets/accessible_button.dart';

/// Data class holding linked user information passed to the detail screen
class LinkedUserData {
  final String relationshipId;
  final String userId;
  final String userName;
  final String? userEmail;
  final String? userPhone;
  final String userCode;
  final bool isEditable;
  final String linkedUserRole;

  const LinkedUserData({
    required this.relationshipId,
    required this.userId,
    required this.userName,
    this.userEmail,
    this.userPhone,
    required this.userCode,
    required this.isEditable,
    required this.linkedUserRole,
  });
}

/// Screen displaying linked user details with option to edit name (caregiver only)
/// and swipe-to-remove functionality
class LinkedUserDetailScreen extends StatefulWidget {
  final LinkedUserData userData;

  const LinkedUserDetailScreen({
    super.key,
    required this.userData,
  });

  @override
  State<LinkedUserDetailScreen> createState() => _LinkedUserDetailScreenState();
}

class _LinkedUserDetailScreenState extends State<LinkedUserDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _userApi = getIt<UserApi>();
  final _relationshipApi = getIt<RelationshipApi>();

  bool _isSaving = false;
  bool _hasChanges = false;

  // Swipe state
  double _dragPosition = 0;
  bool _isDragging = false;
  static const double _thumbSize = 50;
  static const double _triggerThreshold = 0.8;
  static const double _trackPadding = 5;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.userData.userName;
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final changed = _nameController.text.trim() != widget.userData.userName;
    if (changed != _hasChanges) {
      setState(() => _hasChanges = changed);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await _userApi.updateLinkedUserName(
        widget.userData.userId,
        _nameController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated successfully')),
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
            content: Text('Error updating name: $e'),
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

  Future<void> _confirmRemove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Connection'),
        content: Text(
          'Remove ${widget.userData.userName}? This will end the care connection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _removeRelationship();
    }
  }

  Future<void> _removeRelationship() async {
    try {
      await _relationshipApi.deleteRelationship(widget.userData.relationshipId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.userData.userName} removed'),
          ),
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
            content: Text('Error removing connection: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditable = widget.userData.isEditable;
    final roleLabel = widget.userData.linkedUserRole == 'dependent'
        ? 'Dependent Details'
        : 'Caregiver Details';

    return Scaffold(
      appBar: AppBar(
        title: Text(roleLabel),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            // Avatar
            Center(
              child: CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                radius: 48,
                child: Text(
                  _nameController.text.isNotEmpty
                      ? _nameController.text[0].toUpperCase()
                      : '?',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Name field
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                prefixIcon: const Icon(Icons.person_outline),
                suffixIcon: isEditable
                    ? const Icon(Icons.edit_outlined, size: 20)
                    : Icon(
                        Icons.lock_outline,
                        color: colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                filled: !isEditable,
                fillColor: !isEditable
                    ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                    : null,
              ),
              style: !isEditable
                  ? TextStyle(color: colorScheme.onSurfaceVariant)
                  : null,
              readOnly: !isEditable,
              textCapitalization: TextCapitalization.words,
              validator: isEditable
                  ? (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    }
                  : null,
              onChanged: isEditable ? (_) => setState(() {}) : null,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Email field (read-only)
            TextFormField(
              initialValue: widget.userData.userEmail?.isNotEmpty == true
                  ? widget.userData.userEmail
                  : 'Not set',
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email_outlined),
                suffixIcon: Icon(
                  Icons.lock_outline,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              style: TextStyle(color: colorScheme.onSurfaceVariant),
              readOnly: true,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Phone field (read-only)
            TextFormField(
              initialValue: widget.userData.userPhone?.isNotEmpty == true
                  ? widget.userData.userPhone
                  : 'Not set',
              decoration: InputDecoration(
                labelText: 'Phone',
                prefixIcon: const Icon(Icons.phone_outlined),
                suffixIcon: Icon(
                  Icons.lock_outline,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              style: TextStyle(color: colorScheme.onSurfaceVariant),
              readOnly: true,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Unique Code field (read-only)
            TextFormField(
              initialValue: widget.userData.userCode,
              decoration: InputDecoration(
                labelText: 'Unique Code',
                prefixIcon: const Icon(Icons.qr_code),
                suffixIcon: Icon(
                  Icons.lock_outline,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
                letterSpacing: 1,
              ),
              readOnly: true,
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Update/Cancel buttons (only for caregiver editing)
            if (isEditable) ...[
              Row(
                children: [
                  Expanded(
                    child: AccessibleOutlinedButton(
                      onPressed: _isSaving ? null : () => context.pop(),
                      label: 'Cancel',
                      size: AccessibleButtonSize.medium,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AccessibleButton(
                      onPressed: (_isSaving || !_hasChanges) ? null : _saveChanges,
                      label: 'Update',
                      icon: Icons.check,
                      isLoading: _isSaving,
                      size: AccessibleButtonSize.medium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            // Swipe to Remove
            _buildSwipeToRemove(context),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeToRemove(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const height = 60.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final maxDrag = trackWidth - _thumbSize - (_trackPadding * 2);
        final currentProgress = maxDrag > 0 ? _dragPosition / maxDrag : 0.0;

        return Container(
          height: height,
          decoration: BoxDecoration(
            color: colorScheme.errorContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(
              color: colorScheme.error.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              // Progress fill
              AnimatedContainer(
                duration: const Duration(milliseconds: 50),
                width: _dragPosition + _thumbSize + _trackPadding,
                height: height,
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.2 + (currentProgress * 0.3)),
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),

              // Label text (fades as thumb moves)
              Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 100),
                  opacity: (1 - currentProgress).clamp(0.3, 1.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: _thumbSize + _trackPadding),
                      Icon(
                        Icons.arrow_forward,
                        color: colorScheme.error.withValues(alpha: 0.7),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Swipe to Remove',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: _thumbSize),
                    ],
                  ),
                ),
              ),

              // Draggable thumb
              Positioned(
                left: _trackPadding + _dragPosition,
                top: _trackPadding,
                child: GestureDetector(
                  onHorizontalDragStart: (_) {
                    setState(() => _isDragging = true);
                    Haptics.lightImpact();
                  },
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _dragPosition += details.delta.dx;
                      _dragPosition = _dragPosition.clamp(0.0, maxDrag);
                    });
                  },
                  onHorizontalDragEnd: (_) {
                    final threshold = maxDrag * _triggerThreshold;

                    if (_dragPosition >= threshold) {
                      Haptics.heavyImpact();
                      _confirmRemove();
                    }

                    setState(() {
                      _isDragging = false;
                      _dragPosition = 0;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: _thumbSize,
                    height: height - (_trackPadding * 2),
                    decoration: BoxDecoration(
                      color: _isDragging
                          ? colorScheme.error
                          : colorScheme.error.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular((height - (_trackPadding * 2)) / 2),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.error.withValues(alpha: _isDragging ? 0.4 : 0.2),
                          blurRadius: _isDragging ? 8 : 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      currentProgress >= _triggerThreshold
                          ? Icons.person_remove
                          : Icons.chevron_right,
                      color: colorScheme.onError,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
