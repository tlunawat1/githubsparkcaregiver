/// User roles in the application
enum UserRole {
  /// Caregiver who manages reminders and monitors dependents
  caregiver,

  /// Dependent who receives reminders and can trigger SOS
  dependent,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.caregiver:
        return 'Caregiver';
      case UserRole.dependent:
        return 'Dependent';
    }
  }

  String get description {
    switch (this) {
      case UserRole.caregiver:
        return 'Set reminders, manage contacts, and monitor your loved ones';
      case UserRole.dependent:
        return 'Receive reminders and get help when you need it';
    }
  }
}
