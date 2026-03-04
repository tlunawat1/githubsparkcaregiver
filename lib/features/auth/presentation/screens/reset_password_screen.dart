import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/redesign_tokens.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../shared/widgets/redesign_ui.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String role;
  final String email;

  const ResetPasswordScreen({
    super.key,
    required this.role,
    required this.email,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authApi = getIt<AuthApi>();

  bool _isLoading = false;
  bool _isResending = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  int _resendCooldownSeconds = 0;
  Timer? _resendCooldownTimer;

  @override
  void dispose() {
    _resendCooldownTimer?.cancel();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: RedesignBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 430,
                      minHeight: constraints.maxHeight - (AppSpacing.md * 2),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              IconButton.filledTonal(
                                onPressed: () => context.go(
                                  '${AppRoutes.forgotPassword}?role=${widget.role}',
                                ),
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Reset Password',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          GlassCard(
                            margin: EdgeInsets.zero,
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  width: 80.r,
                                  height: 80.r,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        RedesignTokens.primary,
                                        Color(0x8813C8EC),
                                      ],
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.published_with_changes_rounded,
                                    color: Colors.white,
                                    size: 40.r,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                Text(
                                  'Set New Password',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Please enter your 6-digit reset code and your new secure password.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  widget.email,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.md,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.errorContainer,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: colorScheme.onErrorContainer,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                ],
                                TextFormField(
                                  controller: _codeController,
                                  decoration: _inputDecoration(
                                    context,
                                    hintText: '6-digit Reset Code',
                                    prefixIcon: Icons.pin_outlined,
                                  ),
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    letterSpacing: 4,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: (value) {
                                    final v = value?.trim() ?? '';
                                    if (v.length != 6) {
                                      return 'Please enter a 6-digit code';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                TextFormField(
                                  controller: _newPasswordController,
                                  decoration: _inputDecoration(
                                    context,
                                    hintText: 'New Password',
                                    prefixIcon: Icons.lock_outlined,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureNewPassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscureNewPassword =
                                            !_obscureNewPassword,
                                      ),
                                    ),
                                  ),
                                  obscureText: _obscureNewPassword,
                                  textInputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a new password';
                                    }
                                    if (value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  decoration: _inputDecoration(
                                    context,
                                    hintText: 'Confirm New Password',
                                    prefixIcon: Icons.shield_outlined,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscureConfirmPassword =
                                            !_obscureConfirmPassword,
                                      ),
                                    ),
                                  ),
                                  obscureText: _obscureConfirmPassword,
                                  textInputAction: TextInputAction.done,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please confirm your new password';
                                    }
                                    if (value != _newPasswordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                  onFieldSubmitted: (_) => _handleReset(),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                GradientPrimaryButton(
                                  onPressed: _isLoading ? null : _handleReset,
                                  isLoading: _isLoading,
                                  label: 'Reset Password',
                                  icon: Icons.arrow_forward_rounded,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Didn\'t receive a code? ',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (_isResending)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                )
                              else
                                GestureDetector(
                                  onTap: _resendCooldownSeconds > 0
                                      ? null
                                      : _handleResendCode,
                                  child: Text(
                                    _resendCooldownSeconds > 0
                                        ? 'Resend in ${_resendCooldownSeconds}s'
                                        : 'Resend Code',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: _resendCooldownSeconds > 0
                                          ? colorScheme.onSurfaceVariant
                                          : colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                      decoration: _resendCooldownSeconds > 0
                                          ? TextDecoration.none
                                          : TextDecoration.underline,
                                      decorationColor: colorScheme.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(
        prefixIcon,
        color: RedesignTokens.primary.withValues(alpha: 0.7),
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colorScheme.surface.withValues(alpha: 0.7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28.r),
        borderSide: BorderSide(
          color: RedesignTokens.primary.withValues(alpha: 0.25),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28.r),
        borderSide: BorderSide(
          color: RedesignTokens.primary.withValues(alpha: 0.25),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28.r),
        borderSide: BorderSide(
          color: RedesignTokens.primary.withValues(alpha: 0.75),
        ),
      ),
    );
  }

  void _startResendCooldown(int seconds) {
    _resendCooldownTimer?.cancel();
    setState(() => _resendCooldownSeconds = seconds);
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _resendCooldownSeconds = 0);
      } else {
        setState(() => _resendCooldownSeconds -= 1);
      }
    });
  }

  Future<void> _handleResendCode() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final response = await _authApi.requestPasswordReset(
        email: widget.email,
      );

      final retryAfter = response.retryAfterSeconds;
      if (retryAfter != null && retryAfter > 0) {
        _startResendCooldown(retryAfter);
      } else {
        _startResendCooldown(60); // default 60s cooldown
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.message.isNotEmpty
                  ? response.message
                  : 'A new code has been sent to your email.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ApiException catch (e) {
      final retryAfter = (e.data?['retryAfterSeconds'] as num?)?.toInt();
      if (e.statusCode == 429) {
        // Rate-limited — just start cooldown, no error banner
        _startResendCooldown(retryAfter ?? 60);
      } else {
        if (retryAfter != null && retryAfter > 0) {
          _startResendCooldown(retryAfter);
        }
        if (mounted) {
          setState(() {
            _errorMessage = friendlyError(e);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = friendlyError(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _authApi.resetPassword(
        email: widget.email,
        code: _codeController.text.trim(),
        newPassword: _newPasswordController.text,
      );

      if (!response.success) {
        setState(() {
          _errorMessage = response.message.isNotEmpty
              ? friendlyError(Exception(response.message))
              : 'Could not reset password. Please try again.';
          _isLoading = false;
        });
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.message.isNotEmpty
                  ? response.message
                  : 'Password reset successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );

        context.go(AppRoutes.login);
      }
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = friendlyError(e);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = friendlyError(e);
        _isLoading = false;
      });
    }
  }
}
