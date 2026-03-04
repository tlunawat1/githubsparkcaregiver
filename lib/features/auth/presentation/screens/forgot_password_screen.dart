import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../shared/widgets/redesign_ui.dart';
import '../../../../data/datasources/remote/remote.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String role;

  const ForgotPasswordScreen({super.key, required this.role});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authApi = getIt<AuthApi>();

  bool _isLoading = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  String? _errorMessage;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
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
                                  AppRoutes.login,
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
                          const SizedBox(height: AppSpacing.lg),
                          Container(
                            width: 80.r,
                            height: 80.r,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.lock_reset,
                              size: 40.r,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Enter your email and we\'ll send a 6-digit reset code.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          GlassCard(
                            margin: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
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
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                ],
                                Text(
                                  'Email Address',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                TextFormField(
                                  controller: _emailController,
                                  decoration: _inputDecoration(
                                    context,
                                    hintText: 'parent@email.com',
                                    suffixIcon: const Icon(
                                      Icons.mail_outline_rounded,
                                    ),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.done,
                                  autocorrect: false,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!_isValidEmail(value)) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                  onFieldSubmitted: (_) => _handleSendCode(),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                GradientPrimaryButton(
                                  onPressed:
                                      (_isLoading || _cooldownSeconds > 0)
                                      ? null
                                      : _handleSendCode,
                                  isLoading: _isLoading,
                                  label: _cooldownSeconds > 0
                                      ? 'Try again in ${_cooldownSeconds}s'
                                      : 'Send Reset Code',
                                  icon: Icons.send_rounded,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Remember your password? ',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.go(
                                  AppRoutes.login,
                                ),
                                child: const Text('Login'),
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
    Widget? suffixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hintText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colorScheme.surface.withValues(alpha: 0.68),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.75),
          width: 1.2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();

    setState(() {
      _cooldownSeconds = seconds;
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() {
          _cooldownSeconds = 0;
        });
      } else {
        setState(() {
          _cooldownSeconds -= 1;
        });
      }
    });
  }

  Future<void> _handleSendCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim().toLowerCase();

    try {
      final response = await _authApi.requestPasswordReset(email: email);

      final retryAfter = response.retryAfterSeconds;
      if (retryAfter != null && retryAfter > 0) {
        _startCooldown(retryAfter);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.message.isEmpty ? 'Reset code sent' : response.message,
            ),
            backgroundColor: Colors.green,
          ),
        );

        context.go(
          '${AppRoutes.resetPassword}?role=${widget.role}&email=${Uri.encodeComponent(email)}',
        );
      }
    } on ApiException catch (e) {
      final retryAfter = (e.data?['retryAfterSeconds'] as num?)?.toInt();
      if (e.statusCode == 429) {
        _startCooldown(retryAfter ?? 60);
      } else {
        if (retryAfter != null && retryAfter > 0) {
          _startCooldown(retryAfter);
        }
        setState(() {
          _errorMessage = friendlyError(e);
          _isLoading = false;
        });
      }
      return;
    } catch (e) {
      setState(() {
        _errorMessage = friendlyError(e);
        _isLoading = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
