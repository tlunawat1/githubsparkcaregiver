import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/services/fcm_service.dart';
import '../../../../core/theme/redesign_tokens.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../shared/widgets/redesign_ui.dart';

/// The current login mode determines which fields and buttons are shown.
enum _LoginMode {
  /// Normal email + password login.
  password,

  /// User tapped "Login via Code" – password field is hidden, button says "Continue".
  codeEmail,

  /// Verification code was sent – code field is shown, button says "Verify & Login".
  codeVerify,
}

/// Login screen with email/password and login via code options
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  final _authApi = getIt<AuthApi>();
  final _settingsRepository = getIt<SettingsRepository>();
  final _apiClient = getIt<ApiClient>();
  final _signalRService = getIt<SignalRService>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isResendingCode = false;
  int _resendCooldown = 0;
  Timer? _resendTimer;
  String? _errorMessage;
  _LoginMode _loginMode = _LoginMode.password;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
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
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (AppSpacing.md * 2),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                IconButton.filledTonal(
                                  onPressed: () =>
                                      context.go(AppRoutes.onboarding),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'Login',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            GlassCard(
                              margin: EdgeInsets.zero,
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Column(
                                    children: [
                                      Container(
                                        width: 64.r,
                                        height: 64.r,
                                        decoration: BoxDecoration(
                                          color: RedesignTokens.primary
                                              .withValues(alpha: 0.16),
                                          borderRadius: BorderRadius.circular(
                                            32.r,
                                          ),
                                          border: Border.all(
                                            color: RedesignTokens.primary
                                                .withValues(alpha: 0.28),
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.favorite,
                                          size: 34.r,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      Text(
                                        'Welcome Back',
                                        style: theme.textTheme.headlineMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  if (_errorMessage != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(
                                        AppSpacing.md,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.errorContainer,
                                        borderRadius: BorderRadius.circular(14.r),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            color: colorScheme.error,
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Expanded(
                                            child: Text(
                                              _errorMessage!,
                                              style: TextStyle(
                                                color: colorScheme
                                                    .onErrorContainer,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                  ],
                                  Padding(
                                    padding: EdgeInsets.only(left: 12.w, bottom: 6.h),
                                    child: Text(
                                      'Email Address',
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.sp,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                  TextFormField(
                                    controller: _emailController,
                                    decoration: _glassInputDecoration(
                                      context,
                                      hintText: 'parent@example.com',
                                    ),
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
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
                                  ),
                                  // --- Password / Code field (animated) ---
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    alignment: Alignment.topCenter,
                                    child: _loginMode == _LoginMode.codeEmail
                                        // Hide the field entirely when waiting for email-only step.
                                        ? const SizedBox.shrink()
                                        : Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              const SizedBox(height: AppSpacing.md),
                                              AnimatedSwitcher(
                                                duration: const Duration(milliseconds: 250),
                                                layoutBuilder: (currentChild, previousChildren) {
                                                  return Stack(
                                                    alignment: Alignment.centerLeft,
                                                    children: [
                                                      ...previousChildren,
                                                      if (currentChild != null) currentChild,
                                                    ],
                                                  );
                                                },
                                                child: Padding(
                                                  key: ValueKey(_loginMode),
                                                  padding: EdgeInsets.only(left: 12.w, bottom: 6.h),
                                                  child: Text(
                                                    _loginMode == _LoginMode.codeVerify
                                                        ? 'Verification Code'
                                                        : 'Password',
                                                    style: theme.textTheme.labelMedium?.copyWith(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 13.sp,
                                                      letterSpacing: 1.0,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (_loginMode == _LoginMode.codeVerify)
                                                TextFormField(
                                                  key: const ValueKey('code_field'),
                                                  controller: _codeController,
                                                  decoration: _glassInputDecoration(
                                                    context,
                                                    hintText: 'Enter 6-digit code',
                                                  ),
                                                  keyboardType: TextInputType.number,
                                                  textInputAction: TextInputAction.done,
                                                  maxLength: 6,
                                                  autofocus: true,
                                                  validator: (value) {
                                                    if (value == null || value.isEmpty) {
                                                      return 'Please enter the code';
                                                    }
                                                    if (value.length != 6) {
                                                      return 'Code must be 6 digits';
                                                    }
                                                    return null;
                                                  },
                                                  onFieldSubmitted: (_) => _handleVerifyCode(),
                                                )
                                              else
                                                TextFormField(
                                                  key: const ValueKey('password_field'),
                                                  controller: _passwordController,
                                                  decoration: _glassInputDecoration(
                                                    context,
                                                    hintText: '••••••••',
                                                    suffixIcon: IconButton(
                                                      icon: Icon(
                                                        _obscurePassword
                                                            ? Icons.visibility_outlined
                                                            : Icons.visibility_off_outlined,
                                                      ),
                                                      onPressed: () {
                                                        setState(
                                                          () => _obscurePassword =
                                                              !_obscurePassword,
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                  obscureText: _obscurePassword,
                                                  textInputAction: TextInputAction.done,
                                                  validator: (value) {
                                                    if (value == null || value.isEmpty) {
                                                      return 'Please enter your password';
                                                    }
                                                    return null;
                                                  },
                                                  onFieldSubmitted: (_) => _handleLogin(),
                                                ),
                                            ],
                                          ),
                                  ),
                                  // Forgot password (only in password mode)
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    alignment: Alignment.topCenter,
                                    child: _loginMode == _LoginMode.password
                                        ? Padding(
                                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton(
                                                onPressed: _isLoading
                                                    ? null
                                                    : () => context.go(
                                                        '${AppRoutes.forgotPassword}?role=caregiver',
                                                      ),
                                                child: const Text('Forgot password?'),
                                              ),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                  // Info text + resend when code was sent
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    alignment: Alignment.topCenter,
                                    child: _loginMode == _LoginMode.codeVerify
                                        ? Padding(
                                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                                            child: Column(
                                              children: [
                                                Text(
                                                  'A code was sent to ${_emailController.text.trim()}',
                                                  style: theme.textTheme.bodySmall?.copyWith(
                                                    color: colorScheme.onSurfaceVariant,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: AppSpacing.xs),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      'Didn\'t get it? ',
                                                      style: theme.textTheme.bodySmall?.copyWith(
                                                        color: colorScheme.onSurfaceVariant,
                                                      ),
                                                    ),
                                                    _isResendingCode
                                                        ? SizedBox(
                                                            width: 14,
                                                            height: 14,
                                                            child: CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color: colorScheme.primary,
                                                            ),
                                                          )
                                                        : GestureDetector(
                                                            onTap: _resendCooldown > 0
                                                                ? null
                                                                : _handleResendLoginCode,
                                                            child: Text(
                                                              _resendCooldown > 0
                                                                  ? 'Resend in ${_resendCooldown}s'
                                                                  : 'Resend Code',
                                                              style: theme.textTheme.bodySmall?.copyWith(
                                                                color: _resendCooldown > 0
                                                                    ? colorScheme.onSurfaceVariant
                                                                    : colorScheme.primary,
                                                                fontWeight: FontWeight.w700,
                                                                decoration: _resendCooldown > 0
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
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  // --- Primary action button (animated label) ---
                                  GradientPrimaryButton(
                                    onPressed: _isLoading ? null : _primaryAction,
                                    isLoading: _isLoading,
                                    label: _primaryButtonLabel,
                                    icon: _primaryButtonIcon,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  // --- Toggle between password / code mode ---
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: OutlinedButton.icon(
                                      onPressed: _isLoading ? null : _toggleLoginMode,
                                      icon: Icon(
                                        _loginMode == _LoginMode.password
                                            ? Icons.sms_outlined
                                            : Icons.lock_outlined,
                                        size: 20,
                                      ),
                                      label: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 250),
                                        child: Text(
                                          _loginMode == _LoginMode.password
                                              ? 'Login via Code'
                                              : 'Login via Password',
                                          key: ValueKey(_loginMode == _LoginMode.password),
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        textStyle: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                        side: BorderSide(
                                          color: colorScheme.primary.withValues(
                                            alpha: 0.30,
                                          ),
                                        ),
                                        backgroundColor: colorScheme.primary
                                            .withValues(alpha: 0.04),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18.r,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "Don't have an account? ",
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            context.go(AppRoutes.register);
                                          },
                                          child: const Text('Register'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                        ),
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

  InputDecoration _glassInputDecoration(
    BuildContext context, {
    required String hintText,
    Widget? suffixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecoration(
      hintText: hintText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colorScheme.surface.withValues(alpha: 0.66),
      contentPadding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 18.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28.r),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28.r),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28.r),
        borderSide: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.70),
          width: 1.2,
        ),
      ),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  Future<void> _registerFcmToken() async {
    try {
      final fcmService = getIt<FcmService>();
      fcmService.enableRegistration();
      await fcmService.initialize();
      await fcmService.registerDeviceToken();
      debugPrint('FCM token registered after login');
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Computed helpers for the primary action button
  // ---------------------------------------------------------------------------

  String get _primaryButtonLabel => switch (_loginMode) {
    _LoginMode.password   => 'Login',
    _LoginMode.codeEmail  => 'Continue',
    _LoginMode.codeVerify => 'Verify & Login',
  };

  IconData get _primaryButtonIcon => switch (_loginMode) {
    _LoginMode.password   => Icons.login_rounded,
    _LoginMode.codeEmail  => Icons.arrow_forward_rounded,
    _LoginMode.codeVerify => Icons.verified_outlined,
  };

  void _primaryAction() {
    switch (_loginMode) {
      case _LoginMode.password:
        _handleLogin();
      case _LoginMode.codeEmail:
        _handleSendCode();
      case _LoginMode.codeVerify:
        _handleVerifyCode();
    }
  }

  // ---------------------------------------------------------------------------
  // Toggle between password and code-based login
  // ---------------------------------------------------------------------------

  void _toggleLoginMode() {
    setState(() {
      if (_loginMode == _LoginMode.password) {
        // Switch to code flow — clear password, keep email.
        _passwordController.clear();
        _codeController.clear();
        _errorMessage = null;
        _loginMode = _LoginMode.codeEmail;
      } else {
        // Switch back to password flow.
        _codeController.clear();
        _errorMessage = null;
        _loginMode = _LoginMode.password;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Standard email + password login
  // ---------------------------------------------------------------------------

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;

      final response = await _authApi.login(email: email, password: password);

      // Check if email verification is required
      if (response.requiresVerification) {
        if (mounted) {
          context.go(
            '${AppRoutes.emailVerification}?userId=${response.userId}&role=caregiver&email=${Uri.encodeComponent(email)}',
          );
        }
        return;
      }

      _completeLogin(response);
    } catch (e) {
      setState(() {
        _errorMessage = friendlyError(e);
        _isLoading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Code flow – Step 1: send verification code
  // ---------------------------------------------------------------------------

  Future<void> _handleSendCode() async {
    // Only validate the email field in this step.
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !_isValidEmail(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authApi.sendVerificationCode(email: email);

      if (mounted) {
        setState(() {
          _loginMode = _LoginMode.codeVerify;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (e.statusCode == 429) {
        // Rate-limited — show cooldown timer instead of error
        final retryAfter = (e.data?['retryAfterSeconds'] as num?)?.toInt() ?? 60;
        if (mounted) {
          setState(() {
            _loginMode = _LoginMode.codeVerify;
            _isLoading = false;
          });
          _startResendCooldown(retryAfter);
        }
      } else {
        setState(() {
          _errorMessage = friendlyError(e);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = friendlyError(e);
        _isLoading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Code flow – Resend verification code
  // ---------------------------------------------------------------------------

  void _startResendCooldown(int seconds) {
    _resendTimer?.cancel();
    setState(() => _resendCooldown = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown -= 1);
      }
    });
  }

  Future<void> _handleResendLoginCode() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) return;

    setState(() {
      _isResendingCode = true;
      _errorMessage = null;
    });

    try {
      await _authApi.sendVerificationCode(email: email);
      _startResendCooldown(60);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A new code has been sent to your email.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ApiException catch (e) {
      if (e.statusCode == 429) {
        // Rate-limited — just start cooldown, no scary error
        final retryAfter = (e.data?['retryAfterSeconds'] as num?)?.toInt() ?? 60;
        _startResendCooldown(retryAfter);
      } else {
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
      if (mounted) setState(() => _isResendingCode = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Code flow – Step 2: verify code & login
  // ---------------------------------------------------------------------------

  Future<void> _handleVerifyCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      final code = _codeController.text.trim();

      final response = await _authApi.loginWithCode(
        email: email,
        code: code,
      );

      // Check if email verification is required
      if (response.requiresVerification) {
        setState(() {
          _errorMessage = 'Please verify your email first';
          _isLoading = false;
        });
        return;
      }

      _completeLogin(response);
    } catch (e) {
      setState(() {
        _errorMessage = friendlyError(e);
        _isLoading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Shared post-login logic (session, SignalR, FCM, navigation)
  // ---------------------------------------------------------------------------

  Future<void> _completeLogin(LoginResponse response) async {
    final user = response.user;
    if (user == null) {
      setState(() {
        _errorMessage = _loginMode == _LoginMode.codeVerify
            ? 'That code doesn\'t match. Please double-check and try again.'
            : 'Incorrect email or password. Please try again.';
        _isLoading = false;
      });
      return;
    }

    // Save user session (tokens already saved by AuthApi)
    await _settingsRepository.setCurrentUserId(user.id);
    await _settingsRepository.setUserRole(user.role);
    await _settingsRepository.setOnboardingComplete(true);

    // Connect SignalR for real-time updates
    _signalRService.setAccessToken(_apiClient.accessToken);
    _signalRService.connect();

    // Register FCM token for push notifications
    _registerFcmToken();

    debugPrint(
      'Login successful - User role: "${user.role}", navigating to ${user.role == 'caregiver' ? 'caregiverHome' : 'dependentHome'}',
    );

    Haptics.mediumImpact();

    // Route automatically based on the user's registered role.
    if (mounted) {
      if (user.role == 'caregiver') {
        context.go(AppRoutes.caregiverHome);
      } else {
        context.go(AppRoutes.dependentHome);
      }
    }
  }
}
