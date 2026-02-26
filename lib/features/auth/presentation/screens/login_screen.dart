import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/services/fcm_service.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../data/repositories/repositories.dart';

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
      appBar: AppBar(
        title: const Text('Login'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.roleSelection),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),
                // Header
                Icon(
                  widget.role == 'caregiver' ? Icons.favorite : Icons.person,
                  size: 64,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Welcome Back',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Sign in as ${widget.role == 'caregiver' ? 'Caregiver' : 'Dependent'}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),

                // Error message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: colorScheme.error),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: colorScheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Email field
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    prefixIcon: Icon(Icons.email_outlined),
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

                // Password field
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
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
                const SizedBox(height: AppSpacing.xl),

                // Login button
                FilledButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Login'),
                ),
                const SizedBox(height: AppSpacing.md),

                // Login via code button
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _showLoginViaCodeDialog,
                  icon: const Icon(Icons.pin),
                  label: const Text('Login via Code'),
                ),
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
                const SizedBox(height: AppSpacing.xl),

                // Register link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () {
                        context.go('${AppRoutes.register}?role=${widget.role}');
                      },
                      child: const Text('Register'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
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

      debugPrint('Login successful - User role: "${user.role}", navigating to ${user.role == 'caregiver' ? 'caregiverHome' : 'dependentHome'}');

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
                onPressed: isLoading ? null : () async {
                  if (isEmailStep) {
                    final email = emailController.text.trim().toLowerCase();
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
                        dialogError = e.toString().replaceAll('Exception: ', '');
                        isLoading = false;
                      });
                    }
                  } else {
                    final email = emailController.text.trim().toLowerCase();
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
                      final response = await _authApi.loginWithCode(email: email, code: code);

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
                          dialogError = 'This account is registered as a ${user.role}';
                          isLoading = false;
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
                        dialogError = e.toString().replaceAll('Exception: ', '');
                        isLoading = false;
                      });
                    }
                  }
                },
                child: isLoading
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(isEmailStep ? 'Continue' : 'Verify'),
              ),
            ],
          );
        },
      ),
    );
  }
}
