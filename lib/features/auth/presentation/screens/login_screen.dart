import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/services/fcm_service.dart';
import '../../../../core/theme/redesign_tokens.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../shared/widgets/redesign_ui.dart';

/// Login screen with email/password and login via code options
class LoginScreen extends StatefulWidget {
  final String role;

  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authApi = getIt<AuthApi>();
  final _settingsRepository = getIt<SettingsRepository>();
  final _apiClient = getIt<ApiClient>();
  final _signalRService = getIt<SignalRService>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton.filledTonal(
                                onPressed: () =>
                                    context.go(AppRoutes.roleSelection),
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 18,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: colorScheme.surface
                                      .withValues(alpha: 0.65),
                                ),
                              ),
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
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          color: RedesignTokens.primary
                                              .withValues(alpha: 0.16),
                                          borderRadius: BorderRadius.circular(
                                            32,
                                          ),
                                          border: Border.all(
                                            color: RedesignTokens.primary
                                                .withValues(alpha: 0.28),
                                          ),
                                        ),
                                        child: Icon(
                                          widget.role == 'caregiver'
                                              ? Icons.favorite
                                              : Icons.person,
                                          size: 34,
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
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        'Sign in as ${widget.role == 'caregiver' ? 'Caregiver' : 'Dependent'}',
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
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
                                        borderRadius: BorderRadius.circular(14),
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
                                  Text(
                                    'Email Address',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
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
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    'Password',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  TextFormField(
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
                                  const SizedBox(height: AppSpacing.xs),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () => context.go(
                                              '${AppRoutes.forgotPassword}?role=${widget.role}',
                                            ),
                                      child: const Text('Forgot password?'),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  GradientPrimaryButton(
                                    onPressed: _isLoading ? null : _handleLogin,
                                    isLoading: _isLoading,
                                    label: 'Login',
                                    icon: Icons.login_rounded,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  SizedBox(
                                    height: 56,
                                    child: OutlinedButton.icon(
                                      onPressed: _isLoading
                                          ? null
                                          : _showLoginViaCodeDialog,
                                      icon: const Icon(Icons.sms_outlined),
                                      label: const Text('Login via Code'),
                                      style: OutlinedButton.styleFrom(
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
                                            28,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Don't have an account? ",
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          context.go(
                                            '${AppRoutes.register}?role=${widget.role}',
                                          );
                                        },
                                        child: const Text('Register'),
                                      ),
                                    ],
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
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
      final fcmService = FcmService(getIt<UserApi>());
      await fcmService.initialize();
      await fcmService.registerDeviceToken();
      debugPrint('FCM token registered after login');
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

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
            '${AppRoutes.emailVerification}?userId=${response.userId}&role=${widget.role}&email=${Uri.encodeComponent(email)}',
          );
        }
        return;
      }

      // Get user data from auth response
      final user = response.user;
      if (user == null) {
        setState(() {
          _errorMessage = 'Invalid email or password';
          _isLoading = false;
        });
        return;
      }

      // Check if user role matches
      if (user.role != widget.role) {
        setState(() {
          _errorMessage = 'This account is registered as a ${user.role}';
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

      if (mounted) {
        if (user.role == 'caregiver') {
          debugPrint('Navigating to: ${AppRoutes.caregiverHome}');
          context.go(AppRoutes.caregiverHome);
        } else {
          debugPrint('Navigating to: ${AppRoutes.dependentHome}');
          context.go(AppRoutes.dependentHome);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _showLoginViaCodeDialog() {
    final emailController = TextEditingController(text: _emailController.text);
    final codeController = TextEditingController();
    bool isEmailStep = true;
    bool isLoading = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEmailStep ? 'Enter Email' : 'Enter Code'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dialogError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      dialogError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (isEmailStep) ...[
                  const Text('Enter your email to receive a login code.'),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                  ),
                ] else ...[
                  Text(
                    'Enter the 6-digit code sent to ${emailController.text}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      hintText: '6-digit code',
                      prefixIcon: Icon(Icons.pin),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: true,
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (isEmailStep) {
                          final email = emailController.text
                              .trim()
                              .toLowerCase();
                          if (!_isValidEmail(email)) {
                            setDialogState(() {
                              dialogError = 'Please enter a valid email';
                            });
                            return;
                          }

                          setDialogState(() {
                            isLoading = true;
                            dialogError = null;
                          });

                          try {
                            await _authApi.sendVerificationCode(email: email);
                            setDialogState(() {
                              isEmailStep = false;
                              isLoading = false;
                              dialogError = null;
                            });
                          } catch (e) {
                            setDialogState(() {
                              dialogError = e.toString().replaceAll(
                                'Exception: ',
                                '',
                              );
                              isLoading = false;
                            });
                          }
                        } else {
                          final email = emailController.text
                              .trim()
                              .toLowerCase();
                          final code = codeController.text.trim();

                          if (code.length != 6) {
                            setDialogState(() {
                              dialogError = 'Please enter a 6-digit code';
                            });
                            return;
                          }

                          setDialogState(() {
                            isLoading = true;
                            dialogError = null;
                          });

                          try {
                            final response = await _authApi.loginWithCode(
                              email: email,
                              code: code,
                            );

                            // Check if verification is required
                            if (response.requiresVerification) {
                              setDialogState(() {
                                dialogError = 'Please verify your email first';
                                isLoading = false;
                              });
                              return;
                            }

                            final user = response.user;
                            if (user == null) {
                              setDialogState(() {
                                dialogError = 'Invalid code';
                                isLoading = false;
                              });
                              return;
                            }

                            // Check role match
                            if (user.role != widget.role) {
                              setDialogState(() {
                                dialogError =
                                    'This account is registered as a ${user.role}';
                                isLoading = false;
                              });
                              return;
                            }

                            // Save user session (tokens already saved by AuthApi)
                            await _settingsRepository.setCurrentUserId(user.id);
                            await _settingsRepository.setUserRole(user.role);
                            await _settingsRepository.setOnboardingComplete(
                              true,
                            );

                            // Connect SignalR for real-time updates
                            _signalRService.setAccessToken(
                              _apiClient.accessToken,
                            );
                            _signalRService.connect();

                            // Register FCM token for push notifications
                            _registerFcmToken();

                            Haptics.mediumImpact();

                            if (!mounted) return;

                            Navigator.of(this.context).pop();
                            if (user.role == 'caregiver') {
                              this.context.go(AppRoutes.caregiverHome);
                            } else {
                              this.context.go(AppRoutes.dependentHome);
                            }
                          } catch (e) {
                            setDialogState(() {
                              dialogError = e.toString().replaceAll(
                                'Exception: ',
                                '',
                              );
                              isLoading = false;
                            });
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEmailStep ? 'Continue' : 'Verify'),
              ),
            ],
          );
        },
      ),
    );
  }
}
