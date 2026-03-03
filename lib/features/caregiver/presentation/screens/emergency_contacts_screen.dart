import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/redesign_tokens.dart';
import '../../../../data/datasources/local/database.dart';
import '../../../../data/repositories/repositories.dart';
import '../../../../shared/widgets/redesign_ui.dart';
import '../../../../shared/widgets/widgets.dart';

/// Screen for managing emergency contacts for a dependent
class EmergencyContactsScreen extends StatefulWidget {
  final String dependentId;

  const EmergencyContactsScreen({super.key, required this.dependentId});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final _contactRepository = getIt<EmergencyContactRepository>();
  final _userRepository = getIt<UserRepository>();

  User? _dependent;
  List<EmergencyContact> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      _dependent = await _userRepository.getUserById(widget.dependentId);
      _contacts = await _contactRepository.getContactsForDependent(
        widget.dependentId,
      );
    } catch (e) {
      debugPrint('Error loading contacts: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: RedesignBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Emergency Contacts',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (_contacts.isNotEmpty)
                      IconButton.filledTonal(
                        icon: const Icon(Icons.reorder),
                        onPressed: _showReorderDialog,
                        tooltip: 'Reorder contacts',
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const LoadingIndicator()
                    : _contacts.isEmpty
                    ? EmptyState(
                        icon: Icons.contacts_outlined,
                        title: 'No Emergency Contacts',
                        message:
                            'Add contacts who should be notified in case of emergency.',
                        actionLabel: 'Add Contact',
                        onAction: _showAddContactDialog,
                      )
                    : ListView.builder(
                        padding: AppSpacing.screenPadding,
                        itemCount: _contacts.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _buildInfoCard();
                          }
                          final contact = _contacts[index - 1];
                          return _ContactCard(
                            contact: contact,
                            onEdit: () => _showEditContactDialog(contact),
                            onDelete: () => _deleteContact(contact),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddContactDialog,
        backgroundColor: RedesignTokens.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add_rounded),
      ),
    );
  }

  Widget _buildInfoCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 32.r,
            height: 32.r,
            decoration: BoxDecoration(
              color: RedesignTokens.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.info_outline,
              color: RedesignTokens.primary,
              size: 18.r,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'These contacts will be notified when ${_dependent?.name ?? 'the dependent'} triggers an SOS alert.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddContactDialog() {
    _showContactDialog();
  }

  void _showEditContactDialog(EmergencyContact contact) {
    _showContactDialog(existingContact: contact);
  }

  void _showContactDialog({EmergencyContact? existingContact}) {
    final nameController = TextEditingController(text: existingContact?.name);
    final phoneController = TextEditingController(
      text: existingContact?.phoneNumber,
    );
    String? selectedRelationship = existingContact?.relationship;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existingContact == null ? 'Add Contact' : 'Edit Contact'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Contact name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+1 234 567 8900',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: selectedRelationship,
                  decoration: const InputDecoration(
                    labelText: 'Relationship',
                    prefixIcon: Icon(Icons.people),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'family', child: Text('Family')),
                    DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                    DropdownMenuItem(
                      value: 'neighbor',
                      child: Text('Neighbor'),
                    ),
                    DropdownMenuItem(value: 'friend', child: Text('Friend')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedRelationship = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();

                if (name.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all required fields'),
                    ),
                  );
                  return;
                }

                Navigator.pop(context);

                if (existingContact != null) {
                  await _updateContact(
                    existingContact,
                    name: name,
                    phone: phone,
                    relationship: selectedRelationship,
                  );
                } else {
                  await _addContact(
                    name: name,
                    phone: phone,
                    relationship: selectedRelationship,
                  );
                }
              },
              child: Text(existingContact == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addContact({
    required String name,
    required String phone,
    String? relationship,
  }) async {
    try {
      await _contactRepository.createContact(
        id: const Uuid().v4(),
        dependentId: widget.dependentId,
        name: name,
        phoneNumber: phone,
        relationship: relationship,
        priority: _contacts.length + 1,
      );

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$name added')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding contact: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _updateContact(
    EmergencyContact contact, {
    required String name,
    required String phone,
    String? relationship,
  }) async {
    try {
      await _contactRepository.updateContact(
        contact.id,
        EmergencyContactsCompanion(
          name: Value(name),
          phoneNumber: Value(phone),
          relationship: Value(relationship),
        ),
      );

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Contact updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating contact: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteContact(EmergencyContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Are you sure you want to delete ${contact.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _contactRepository.deleteContact(contact.id);
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${contact.name} deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting contact: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  void _showReorderDialog() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reordering coming soon')));
  }
}

class _ContactCard extends StatelessWidget {
  final EmergencyContact contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContactCard({
    required this.contact,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final relationshipLabel = switch (contact.relationship) {
      'family' => 'Family',
      'doctor' => 'Doctor',
      'neighbor' => 'Neighbor',
      'friend' => 'Friend',
      'other' => 'Other',
      _ => null,
    };

    return GlassCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          // Priority number
          Container(
            width: 32.r,
            height: 32.r,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                contact.priority.toString(),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Contact info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      contact.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (relationshipLabel != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: RedesignTokens.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          relationshipLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: RedesignTokens.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  contact.phoneNumber,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Actions
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: onEdit,
            tooltip: 'Edit',
          ),
          IconButton(
            icon: Icon(Icons.delete, color: colorScheme.error),
            onPressed: onDelete,
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}
