import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/redesign_tokens.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../shared/widgets/redesign_ui.dart';
import '../../domain/auth_service.dart';

/// Registration screen for new users
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

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
  String? _roleError;

  /// Selected role — required before registration can proceed.
  String? _selectedRole;

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
                                onPressed: () => context.go(AppRoutes.login),
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Start Your Journey',
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
                                width: 58.r,
                                height: 58.r,
                                decoration: BoxDecoration(
                                  color: RedesignTokens.primary.withValues(
                                    alpha: 0.20,
                                  ),
                                  borderRadius: BorderRadius.circular(18.r),
                                  border: Border.all(
                                    color: RedesignTokens.primary.withValues(
                                      alpha: 0.30,
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  Icons.family_restroom,
                                  size: 34.r,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'Care begins with a simple step.',
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
                                      borderRadius: BorderRadius.circular(14.r),
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
                                _FieldLabel(text: 'I am a... *'),
                                Container(
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface.withValues(alpha: 0.70),
                                    borderRadius: BorderRadius.circular(16.r),
                                    border: Border.all(
                                      color: _roleError != null
                                          ? colorScheme.error
                                          : colorScheme.outlineVariant.withValues(alpha: 0.55),
                                      width: _roleError != null ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: RadioGroup<String>(
                                    groupValue: _selectedRole ?? '',
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedRole = value;
                                        _roleError = null;
                                      });
                                    },
                                    child: Column(
                                      children: [
                                        RadioListTile<String>(
                                          title: Text(
                                            'Companion',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'Create reminders & care for loved ones',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          value: 'caregiver',
                                          toggleable: true,
                                          activeColor: RedesignTokens.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12.r),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.sm,
                                          ),
                                        ),
                                        Divider(
                                          height: 1,
                                          indent: AppSpacing.md,
                                          endIndent: AppSpacing.md,
                                          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                                        ),
                                        RadioListTile<String>(
                                          title: Text(
                                            'Loved One',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'Receive reminders & stay connected',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          value: 'dependent',
                                          toggleable: true,
                                          activeColor: RedesignTokens.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12.r),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.sm,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_roleError != null)
                                  Padding(
                                    padding: EdgeInsets.only(left: 14.w, top: 6.h),
                                    child: Text(
                                      _roleError!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.error,
                                      ),
                                    ),
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
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Already have an account? ',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          context.go(AppRoutes.login);
                                        },
                                        child: const Text('Login'),
                                      ),
                                    ],
                                  ),
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
    );
  }

  Future<void> _handleRegister() async {
    final formValid = _formKey.currentState!.validate();

    // Always validate role selection alongside form fields
    if (_selectedRole == null) {
      setState(() => _roleError = 'Please select a role to continue');
    }

    if (!formValid || _selectedRole == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;
      final phone = _phoneController.text.trim();
      final role = _selectedRole!;

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
        role: role,
        phoneNumber: phone.isEmpty ? null : phone,
        timezone: deviceTimezone,
      );

      Haptics.mediumImpact();

      if (mounted) {
        // Navigate to email verification with email for login after verification
        context.go(
          '${AppRoutes.emailVerification}?userId=${response.id}&role=$role&email=${Uri.encodeComponent(email)}',
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = friendlyError(e);
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
      padding: EdgeInsets.only(left: 12.w, bottom: 6.h),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 13.sp,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
