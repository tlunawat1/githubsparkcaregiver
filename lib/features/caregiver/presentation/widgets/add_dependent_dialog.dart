import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../data/datasources/local/database.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../auth/domain/auth_service.dart';

/// Dialog for adding a dependent by unique code or email
class AddDependentDialog extends StatefulWidget {
  final String caregiverId;
  final VoidCallback onDependentAdded;

  const AddDependentDialog({
    super.key,
    required this.caregiverId,
    required this.onDependentAdded,
  });

  @override
  State<AddDependentDialog> createState() => _AddDependentDialogState();
}

class _AddDependentDialogState extends State<AddDependentDialog> {
  final _userRepository = getIt<UserRepository>();
  final _careRelationshipRepository = getIt<CareRelationshipRepository>();
  final _authService = AuthService();

  final _codeController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String _inputMode = 'code'; // 'code' or 'email'

  // For verification step
  bool _showVerificationStep = false;
  User? _foundDependent;
  CareRelationship? _pendingRelationship;
  final _verificationCodeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    _emailController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Text(_showVerificationStep ? 'Verify Connection' : 'Add Dependent'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: colorScheme.error, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: colorScheme.onErrorContainer,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (!_showVerificationStep) ...[
              // Input mode selection
              Row(
                children: [
                  Expanded(
                    child: _buildModeButton(
                      'code',
                      'Unique Code',
                      Icons.qr_code,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildModeButton(
                      'email',
                      'Email',
                      Icons.email,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Input field based on mode
              if (_inputMode == 'code') ...[
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Dependent\'s Code',
                    hintText: 'e.g., A1B2C3D4E',
                    prefixIcon: Icon(Icons.qr_code),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 9,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Ask your dependent to share their 9-character unique code from their profile.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Dependent\'s Email',
                    hintText: 'Enter email address',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Enter the email address your dependent used to register.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ] else ...[
              // Verification step
              _buildVerificationStep(theme, colorScheme),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  if (_showVerificationStep) {
                    setState(() {
                      _showVerificationStep = false;
                      _errorMessage = null;
                      _verificationCodeController.clear();
                    });
                  } else {
                    Navigator.pop(context);
                  }
                },
          child: Text(_showVerificationStep ? 'Back' : 'Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading
              ? null
              : (_showVerificationStep ? _verifyAndConnect : _findDependent),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_showVerificationStep ? 'Verify' : 'Find Dependent'),
        ),
      ],
    );
  }

  Widget _buildModeButton(String mode, String label, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _inputMode == mode;

    return InkWell(
      onTap: () {
        setState(() {
          _inputMode = mode;
          _errorMessage = null;
        });
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? colorScheme.primary : colorScheme.onSurface,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationStep(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Found dependent info
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primary,
                child: Text(
                  _foundDependent?.name.isNotEmpty == true
                      ? _foundDependent!.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _foundDependent?.name ?? 'Unknown',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Dependent',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.check_circle, color: colorScheme.primary),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Instructions
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: colorScheme.secondary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Verification Required',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${_foundDependent?.name ?? 'The dependent'} will see a notification with a 5-digit code. Ask them to share it with you.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  'For testing, use code: 12345',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Verification code input
        TextField(
          controller: _verificationCodeController,
          decoration: const InputDecoration(
            labelText: 'Verification Code',
            hintText: '12345',
            prefixIcon: Icon(Icons.pin),
          ),
          keyboardType: TextInputType.number,
          maxLength: 5,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            letterSpacing: 8,
          ),
        ),
      ],
    );
  }

  Future<void> _findDependent() async {
    setState(() {
      _errorMessage = null;
    });

    String identifier;
    bool isEmail = _inputMode == 'email';

    if (isEmail) {
      identifier = _emailController.text.trim().toLowerCase();
      if (identifier.isEmpty || !_authService.isValidEmail(identifier)) {
        setState(() {
          _errorMessage = 'Please enter a valid email address';
        });
        return;
      }
    } else {
      identifier = _codeController.text.trim().toUpperCase();
      if (identifier.isEmpty || identifier.length != 9) {
        setState(() {
          _errorMessage = 'Please enter a valid 9-character code';
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Find the dependent user
      User? dependent;
      if (isEmail) {
        dependent = await _userRepository.getUserByEmail(identifier);
      } else {
        dependent = await _userRepository.getUserByUniqueCode(identifier);
      }

      if (dependent == null) {
        setState(() {
          _errorMessage = isEmail
              ? 'No account found with this email'
              : 'No account found with this code';
          _isLoading = false;
        });
        return;
      }

      // Check if it's a dependent account
      if (dependent.role != 'dependent') {
        setState(() {
          _errorMessage = 'This account is not registered as a dependent';
          _isLoading = false;
        });
        return;
      }

      // Check if relationship already exists
      final existingActive = await _careRelationshipRepository.relationshipExists(
        widget.caregiverId,
        dependent.id,
      );
      if (existingActive) {
        setState(() {
          _errorMessage = '${dependent?.name} is already connected with you';
          _isLoading = false;
        });
        return;
      }

      // Check if pending relationship exists
      final existingPending =
          await _careRelationshipRepository.pendingRelationshipExists(
        widget.caregiverId,
        dependent.id,
      );
      if (existingPending) {
        setState(() {
          _errorMessage =
              'A pending connection request already exists for ${dependent?.name}';
          _isLoading = false;
        });
        return;
      }

      // Create pending relationship
      final relationshipId = const Uuid().v4();
      final relationship =
          await _careRelationshipRepository.createPendingRelationship(
        id: relationshipId,
        caregiverId: widget.caregiverId,
        dependentId: dependent.id,
        initiatedBy: 'caregiver',
      );

      setState(() {
        _foundDependent = dependent;
        _pendingRelationship = relationship;
        _showVerificationStep = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyAndConnect() async {
    final code = _verificationCodeController.text.trim();
    if (code.length != 5) {
      setState(() {
        _errorMessage = 'Please enter the 5-digit code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _careRelationshipRepository.verifyLinkingCode(
        _pendingRelationship!.id,
        code,
      );

      if (!success) {
        setState(() {
          _errorMessage = 'Invalid verification code. Please try again.';
          _isLoading = false;
        });
        return;
      }

      // Success! Close dialog and notify
      if (mounted) {
        Navigator.pop(context);
        widget.onDependentAdded();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_foundDependent?.name} has been added'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }
}
