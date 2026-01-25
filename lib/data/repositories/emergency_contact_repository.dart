import 'package:drift/drift.dart';
import '../datasources/local/database.dart';

/// Repository for emergency contact-related database operations
class EmergencyContactRepository {
  final AppDatabase _db;

  EmergencyContactRepository(this._db);

  /// Get all emergency contacts for a dependent
  Future<List<EmergencyContact>> getContactsForDependent(String dependentId) {
    return (_db.select(_db.emergencyContacts)
          ..where((c) => c.dependentId.equals(dependentId))
          ..where((c) => c.isActive.equals(true))
          ..orderBy([(c) => OrderingTerm.asc(c.priority)]))
        .get();
  }

  /// Get contact by ID
  Future<EmergencyContact?> getContactById(String id) {
    return (_db.select(_db.emergencyContacts)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  /// Create a new emergency contact
  Future<void> createContact({
    required String id,
    required String dependentId,
    required String name,
    required String phoneNumber,
    String? relationship,
    int priority = 1,
  }) {
    return _db.into(_db.emergencyContacts).insert(
          EmergencyContactsCompanion.insert(
            id: id,
            dependentId: dependentId,
            name: name,
            phoneNumber: phoneNumber,
            relationship: Value(relationship),
            priority: Value(priority),
          ),
        );
  }

  /// Update an emergency contact
  Future<bool> updateContact(
      String id, EmergencyContactsCompanion contact) {
    return (_db.update(_db.emergencyContacts)..where((c) => c.id.equals(id)))
        .write(contact)
        .then((rows) => rows > 0);
  }

  /// Delete an emergency contact (soft delete)
  Future<bool> deleteContact(String id) {
    return updateContact(
      id,
      const EmergencyContactsCompanion(isActive: Value(false)),
    );
  }

  /// Permanently delete a contact
  Future<int> hardDeleteContact(String id) {
    return (_db.delete(_db.emergencyContacts)..where((c) => c.id.equals(id)))
        .go();
  }

  /// Update contact priorities
  Future<void> updateContactPriorities(List<String> contactIds) async {
    for (var i = 0; i < contactIds.length; i++) {
      await updateContact(
        contactIds[i],
        EmergencyContactsCompanion(priority: Value(i + 1)),
      );
    }
  }

  /// Watch contacts for a dependent
  Stream<List<EmergencyContact>> watchContactsForDependent(String dependentId) {
    return (_db.select(_db.emergencyContacts)
          ..where((c) => c.dependentId.equals(dependentId))
          ..where((c) => c.isActive.equals(true))
          ..orderBy([(c) => OrderingTerm.asc(c.priority)]))
        .watch();
  }
}
