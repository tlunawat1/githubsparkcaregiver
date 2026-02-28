import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/redesign_tokens.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../shared/widgets/redesign_ui.dart';
import '../../domain/auth_service.dart';

/// Registration screen for new users
class RegistrationScreen extends StatefulWidget {
  final String role;

  const RegistrationScreen({super.key, required this.role});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _authApi = getIt<AuthApi>();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
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
                      maxWidth: 440,
                      minHeight: constraints.maxHeight - (AppSpacing.md * 2),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton.filledTonal(
                                onPressed: () => context.go(
                                  '${AppRoutes.login}?role=${widget.role}',
                                ),
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Create Account',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Column(
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: RedesignTokens.primary.withValues(
                                    alpha: 0.20,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: RedesignTokens.primary.withValues(
                                      alpha: 0.30,
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  Icons.family_restroom,
                                  size: 34,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'Join Parental Care',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Professional remote care for your loved ones.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
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
                                _FieldLabel(text: 'Full Name *'),
                                TextFormField(
                                  controller: _nameController,
                                  decoration: _glassInputDecoration(
                                    context,
                                    hintText: 'John Doe',
                                    prefixIcon: Icons.person_outline_rounded,
                                  ),
                                  textCapitalization: TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter your name';
                                    }
                                    if (value.trim().length < 2) {
                                      return 'Name must be at least 2 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppSpacing.md),
                                _FieldLabel(text: 'Email *'),
                                TextFormField(
                                  controller: _emailController,
                                  decoration: _glassInputDecoration(
                                    context,
                                    hintText: 'example@email.com',
                                    prefixIcon: Icons.mail_outline_rounded,
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!_authService.isValidEmail(value)) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppSpacing.md),
                                _FieldLabel(text: 'Password *'),
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
                                  textInputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a password';
                                    }
                                    if (!_authService.isValidPassword(value)) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppSpacing.md),
                                _FieldLabel(text: 'Confirm *'),
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  decoration: _glassInputDecoration(
                                    context,
                                    hintText: '••••••••',
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureConfirmPassword =
                                              !_obscureConfirmPassword;
                                        });
                                      },
                                    ),
                                  ),
                                  obscureText: _obscureConfirmPassword,
                                  textInputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please confirm your password';
                                    }
                                    if (value != _passwordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppSpacing.md),
                                _FieldLabel(text: 'Phone Number (Optional)'),
                                TextFormField(
                                  controller: _phoneController,
                                  decoration: _glassInputDecoration(
                                    context,
                                    hintText: '+1 (555) 000-0000',
                                    prefixIcon: Icons.phone_iphone_rounded,
                                  ),
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.done,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                GradientPrimaryButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _handleRegister,
                                  isLoading: _isLoading,
                                  label: 'Create Account',
                                  icon: Icons.arrow_forward_rounded,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Already have an account? ',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        context.go(
                                          '${AppRoutes.login}?role=${widget.role}',
                                        );
                                      },
                                      child: const Text('Login'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'By registering, you agree to Parental Care\'s Terms of Service and Privacy Policy.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
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

  InputDecoration _glassInputDecoration(
    BuildContext context, {
    required String hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colorScheme.surface.withValues(alpha: 0.70),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.75),
          width: 1.2,
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;
      final phone = _phoneController.text.trim();

      // Detect device timezone
      String? deviceTimezone;
      try {
        final tz = await FlutterTimezone.getLocalTimezone();
        deviceTimezone = tz.identifier;
      } catch (e) {
        debugPrint('Could not detect timezone: $e');
      }

      // Register via remote API
      final response = await _authApi.register(
        name: name,
        email: email,
        password: password,
        role: widget.role,
        phoneNumber: phone.isEmpty ? null : phone,
        timezone: deviceTimezone,
      );

      Haptics.mediumImpact();

      if (mounted) {
        // Navigate to email verification with email for login after verification
        context.go(
          '${AppRoutes.emailVerification}?userId=${response.id}&role=${widget.role}&email=${Uri.encodeComponent(email)}',
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 6),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
