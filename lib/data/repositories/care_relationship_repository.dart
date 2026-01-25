import 'package:drift/drift.dart';
import '../datasources/local/database.dart';

/// Repository for care relationship database operations
class CareRelationshipRepository {
  final AppDatabase _db;

  CareRelationshipRepository(this._db);

  /// Get all relationships for a caregiver
  Future<List<CareRelationship>> getRelationshipsForCaregiver(
      String caregiverId) {
    return (_db.select(_db.careRelationships)
          ..where((r) => r.caregiverId.equals(caregiverId))
          ..where((r) => r.status.equals('active')))
        .get();
  }

  /// Get all relationships for a dependent
  Future<List<CareRelationship>> getRelationshipsForDependent(
      String dependentId) {
    return (_db.select(_db.careRelationships)
          ..where((r) => r.dependentId.equals(dependentId))
          ..where((r) => r.status.equals('active')))
        .get();
  }

  /// Get relationship by ID
  Future<CareRelationship?> getRelationshipById(String id) {
    return (_db.select(_db.careRelationships)..where((r) => r.id.equals(id)))
        .getSingleOrNull();
  }

  /// Check if relationship exists
  Future<bool> relationshipExists(String caregiverId, String dependentId) async {
    final relationship = await (_db.select(_db.careRelationships)
          ..where((r) => r.caregiverId.equals(caregiverId))
          ..where((r) => r.dependentId.equals(dependentId))
          ..where((r) => r.status.equals('active')))
        .getSingleOrNull();
    return relationship != null;
  }

  /// Create a new care relationship
  Future<void> createRelationship({
    required String id,
    required String caregiverId,
    required String dependentId,
    String status = 'active',
  }) {
    return _db.into(_db.careRelationships).insert(
          CareRelationshipsCompanion.insert(
            id: id,
            caregiverId: caregiverId,
            dependentId: dependentId,
            status: Value(status),
          ),
        );
  }

  /// Update relationship status
  Future<bool> updateRelationshipStatus(String id, String status) {
    return (_db.update(_db.careRelationships)..where((r) => r.id.equals(id)))
        .write(CareRelationshipsCompanion(
          status: Value(status),
        ))
        .then((rows) => rows > 0);
  }

  /// Delete a relationship
  Future<int> deleteRelationship(String id) {
    return (_db.delete(_db.careRelationships)..where((r) => r.id.equals(id)))
        .go();
  }

  /// Watch relationships for a caregiver
  Stream<List<CareRelationship>> watchRelationshipsForCaregiver(
      String caregiverId) {
    return (_db.select(_db.careRelationships)
          ..where((r) => r.caregiverId.equals(caregiverId))
          ..where((r) => r.status.equals('active')))
        .watch();
  }
}
