import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/redesign_tokens.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../shared/widgets/redesign_ui.dart';
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
  final _userApi = getIt<UserApi>();
  final _relationshipApi = getIt<RelationshipApi>();
  final _authService = AuthService();

  final _codeController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String _inputMode = 'code'; // 'code' or 'email'

  // For verification step
  bool _showVerificationStep = false;
  UserSearchResult? _foundDependent;
  CreateRelationshipResponse? _pendingRelationship;
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

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: GlassCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
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
                      icon: Icon(
                        _showVerificationStep
                            ? Icons.arrow_back_rounded
                            : Icons.close_rounded,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _ProgressPill(active: true),
                        const SizedBox(width: 6),
                        _ProgressPill(active: _showVerificationStep),
                      ],
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.help_outline_rounded,
                      color: Colors.transparent,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _showVerificationStep
                      ? 'Verify Connection'
                      : 'Find Your Loved One',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _showVerificationStep
                      ? 'Step 2 of 2: Enter the linking code provided by your loved one.'
                      : 'Step 1 of 2: Enter the unique connection details provided to your family member.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: colorScheme.onErrorContainer,
                        fontSize: 13.sp,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (!_showVerificationStep) ...[
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
                          'Email Address',
                          Icons.email,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_inputMode == 'code') ...[
                    TextField(
                      controller: _codeController,
                      decoration: _inputDecoration(
                        context,
                        hint: 'Enter 9-character code',
                        icon: Icons.tag_rounded,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 9,
                    ),
                    Text(
                      'Codes are case-sensitive and valid for 24 hours.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    TextField(
                      controller: _emailController,
                      decoration: _inputDecoration(
                        context,
                        hint: 'Enter email address',
                        icon: Icons.mail_outline_rounded,
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ] else ...[
                  _buildVerificationStep(theme, colorScheme),
                ],
                const SizedBox(height: AppSpacing.md),
                GradientPrimaryButton(
                  onPressed: _isLoading
                      ? null
                      : (_showVerificationStep
                            ? _verifyAndConnect
                            : _findDependent),
                  isLoading: _isLoading,
                  label: _showVerificationStep ? 'Verify' : 'Find Loved One',
                  icon: Icons.arrow_forward_rounded,
                ),
                const SizedBox(height: AppSpacing.xs),
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(String mode, String label, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _inputMode == mode;

    return InkWell(
      onTap: () {
        setState(() {
          _inputMode = mode;
          _errorMessage = null;
        });
      },
      borderRadius: BorderRadius.circular(AppRadius.circular),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.surface
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.circular),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16.r,
              color: isSelected
                  ? RedesignTokens.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? RedesignTokens.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String hint,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: RedesignTokens.primary),
      filled: true,
      fillColor: colorScheme.surface.withValues(alpha: 0.9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(
          color: RedesignTokens.primary.withValues(alpha: 0.8),
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
                      'Loved One',
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
                '${_foundDependent?.name ?? 'Your loved one'} will see a notification with a 5-digit code. Ask them to share it with you.',
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
                    fontSize: 12.sp,
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
          style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 8),
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
      // Find the dependent user from remote API
      UserSearchResult dependent;
      try {
        if (isEmail) {
          dependent = await _userApi.findByEmail(identifier);
        } else {
          dependent = await _userApi.findByUniqueCode(identifier);
        }
      } catch (e) {
        // API returns 404 if user not found
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
          _errorMessage = 'This account is not registered as a loved one';
          _isLoading = false;
        });
        return;
      }

      // Create pending relationship via remote API
      // The API will check for existing relationships and return appropriate errors
      try {
        final relationship = await _relationshipApi.createRelationship(
          targetUserIdentifier: identifier,
          initiatedBy: 'caregiver',
        );

        debugPrint(
          'Relationship created: ${relationship.id}, status: ${relationship.status}',
        );

        setState(() {
          _foundDependent = dependent;
          _pendingRelationship = relationship;
          _showVerificationStep = true;
          _isLoading = false;
        });
      } catch (e) {
        debugPrint('Error creating relationship: $e');
        String errorMsg = 'Failed to create connection request';
        if (e.toString().contains('already exists') ||
            e.toString().contains('409')) {
          errorMsg =
              '${dependent.name} is already connected or has a pending request';
        }
        setState(() {
          _errorMessage = errorMsg;
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('Error finding dependent: $e');
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
      debugPrint(
        'Verifying relationship ${_pendingRelationship!.id} with code: $code',
      );
      final response = await _relationshipApi.verifyLinkingCode(
        relationshipId: _pendingRelationship!.id,
        code: code,
      );

      debugPrint(
        'Verification response: success=${response.success}, message=${response.message}',
      );

      if (!response.success) {
        setState(() {
          _errorMessage = response.message.isNotEmpty
              ? response.message
              : 'Invalid verification code. Please try again.';
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
      debugPrint('Error verifying relationship: $e');
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
        _isLoading = false;
      });
    }
  }
}

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26.r,
      height: 6.r,
      decoration: BoxDecoration(
        color: active
            ? RedesignTokens.primary
            : Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}
