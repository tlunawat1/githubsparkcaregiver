import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../shared/widgets/redesign_ui.dart';

/// Email verification screen for confirming user email
class EmailVerificationScreen extends StatefulWidget {
  final String userId;
  final String role;
  final String email;

  const EmailVerificationScreen({
    super.key,
    required this.userId,
    required this.role,
    required this.email,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _codeController = TextEditingController();
  final _authApi = getIt<AuthApi>();
  final _settingsRepository = getIt<SettingsRepository>();
  final _apiClient = getIt<ApiClient>();
  final _signalRService = getIt<SignalRService>();

  bool _isLoading = false;
  bool _isResending = false;
  int _resendCooldownSeconds = 0;
  Timer? _resendCooldownTimer;
  String? _errorMessage;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
  }

  Future<void> _loadUserEmail() async {
    // Email is passed from registration screen
    if (widget.email.isNotEmpty) {
      setState(() {
        _userEmail = widget.email;
      });
    }
  }

  @override
  void dispose() {
    _resendCooldownTimer?.cancel();
    _codeController.dispose();
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            IconButton.filledTonal(
                              onPressed: () => context.go(
                                AppRoutes.register,
                              ),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Security',
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
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.18,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.mark_email_read_outlined,
                                  size: 42.r,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                'Verify Email',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Enter the 6-digit code sent to your email. It expires in 10 minutes.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (_userEmail != null) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  _userEmail!,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              const SizedBox(height: AppSpacing.md),
                              if (_errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(14.r),
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
                              _buildCodeInputs(context),
                              const SizedBox(height: AppSpacing.lg),
                              GradientPrimaryButton(
                                onPressed: _isLoading ? null : _handleVerify,
                                isLoading: _isLoading,
                                label: 'Verify Email',
                                icon: Icons.arrow_forward_rounded,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
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
                                          : _handleResend,
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
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Secure Encryption Active',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ],
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

  String get _verificationCode => _codeController.text.trim();

  Widget _buildCodeInputs(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: _codeController,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 8,
      ),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        hintText: 'Enter 6-digit code',
        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          letterSpacing: 1,
        ),
        filled: true,
        fillColor: colorScheme.surface.withValues(alpha: 0.72),
        contentPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.r),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.r),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.r),
          borderSide: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.75),
            width: 1.2,
          ),
        ),
      ),
    );
  }

  Future<void> _handleVerify() async {
    final code = _verificationCode;
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a 6-digit code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // First verify the email
      await _authApi.verifyEmail(userId: widget.userId, code: code);

      // Then login with code to get auth tokens
      if (widget.email.isNotEmpty) {
        await _authApi.loginWithCode(email: widget.email, code: code);
      }

      // Save user session
      await _settingsRepository.setCurrentUserId(widget.userId);
      await _settingsRepository.setUserRole(widget.role);
      await _settingsRepository.setOnboardingComplete(true);

      // Connect SignalR for real-time updates
      _signalRService.setAccessToken(_apiClient.accessToken);
      _signalRService.connect();

      Haptics.mediumImpact();

      if (mounted) {
        // Show success toast
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email verified! Copy and share your code to connect.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate to home screen
        if (widget.role == 'caregiver') {
          context.go(AppRoutes.caregiverHome);
        } else {
          context.go(AppRoutes.dependentHome);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = friendlyError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _handleResend() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final response = await _authApi.resendVerificationCode(
        userId: widget.userId,
      );
      _startResendCooldown(
        response.retryAfterSeconds != null && response.retryAfterSeconds! > 0
            ? response.retryAfterSeconds!
            : 60,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.message.isEmpty
                  ? 'Verification code sent'
                  : response.message,
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ApiException catch (e) {
      final retryAfter = (e.data?['retryAfterSeconds'] as num?)?.toInt();
      if (e.statusCode == 429) {
        _startResendCooldown(retryAfter ?? 60);
      } else {
        if (retryAfter != null && retryAfter > 0) {
          _startResendCooldown(retryAfter);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(friendlyError(e)),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }

    setState(() {
      _isResending = false;
    });
  }

  void _startResendCooldown(int seconds) {
    _resendCooldownTimer?.cancel();
    setState(() {
      _resendCooldownSeconds = seconds;
    });

    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_resendCooldownSeconds <= 1) {
        timer.cancel();
        setState(() {
          _resendCooldownSeconds = 0;
        });
        return;
      }

      setState(() {
        _resendCooldownSeconds--;
      });
    });
  }
}
