import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../data/datasources/remote/remote.dart';
import '../../../../shared/widgets/accessible_button.dart';

/// Screen for editing user profile information
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _userApi = getIt<UserApi>();

  String _email = '';
  String? _phone;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _userApi.getCurrentUser();
      _nameController.text = userData.name;
      _email = userData.email;
      _phone = userData.phoneNumber;
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await _userApi.updateCurrentUser(name: _nameController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
        context.pop(true); // Return true to indicate profile was updated
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            // Avatar
            Center(
              child: CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                radius: 48,
                child: Text(
                  _nameController.text.isNotEmpty
                      ? _nameController.text[0].toUpperCase()
                      : '?',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Name field (editable)
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                if (value.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
              onChanged: (_) {
                // Update avatar when name changes
                setState(() {});
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // Email field (read-only)
            TextFormField(
              initialValue: _email.isEmpty ? 'Not set' : _email,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email_outlined),
                suffixIcon: Icon(
                  Icons.lock_outline,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                helperText: 'Email cannot be changed',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              style: TextStyle(color: colorScheme.onSurfaceVariant),
              readOnly: true,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Phone field (read-only)
            TextFormField(
              initialValue: _phone?.isNotEmpty == true ? _phone : 'Not set',
              decoration: InputDecoration(
                labelText: 'Phone',
                prefixIcon: const Icon(Icons.phone_outlined),
                suffixIcon: Icon(
                  Icons.lock_outline,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                helperText: 'Phone cannot be changed',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              style: TextStyle(color: colorScheme.onSurfaceVariant),
              readOnly: true,
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: AccessibleOutlinedButton(
                    onPressed: _isSaving ? null : () => context.pop(),
                    label: 'Cancel',
                    size: AccessibleButtonSize.medium,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AccessibleButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    label: 'Update',
                    icon: Icons.check,
                    isLoading: _isSaving,
                    size: AccessibleButtonSize.medium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
