import 'package:drift/drift.dart';
import '../datasources/local/database.dart';
import '../../features/auth/domain/auth_service.dart';

/// Repository for care relationship database operations
class CareRelationshipRepository {
  final AppDatabase _db;
  final AuthService _authService = AuthService();

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
    String initiatedBy = 'caregiver',
  }) {
    return _db.into(_db.careRelationships).insert(
          CareRelationshipsCompanion.insert(
            id: id,
            caregiverId: caregiverId,
            dependentId: dependentId,
            status: Value(status),
            initiatedBy: initiatedBy,
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

  // ============================================
  // Dependent Linking Methods
  // ============================================

  /// Create a pending relationship with linking code
  /// Used when caregiver initiates linking with a dependent
  Future<CareRelationship> createPendingRelationship({
    required String id,
    required String caregiverId,
    required String dependentId,
    required String initiatedBy,
  }) async {
    final linkingCode = AuthService.mvpLinkingCode; // Use hardcoded for MVP
    final codeExpiry = _authService.getLinkingCodeExpiry();

    await _db.into(_db.careRelationships).insert(
          CareRelationshipsCompanion.insert(
            id: id,
            caregiverId: caregiverId,
            dependentId: dependentId,
            status: const Value('pending'),
            linkingCode: Value(linkingCode),
            codeExpiresAt: Value(codeExpiry),
            initiatedBy: initiatedBy,
            verificationAttempts: const Value(0),
          ),
        );

    return (await getRelationshipById(id))!;
  }

  /// Get all pending link requests for a dependent
  Future<List<CareRelationship>> getPendingLinksForDependent(
      String dependentId) {
    return (_db.select(_db.careRelationships)
          ..where((r) => r.dependentId.equals(dependentId))
          ..where((r) => r.status.equals('pending')))
        .get();
  }

  /// Watch pending link requests for a dependent (for notifications)
  Stream<List<CareRelationship>> watchPendingLinksForDependent(
      String dependentId) {
    return (_db.select(_db.careRelationships)
          ..where((r) => r.dependentId.equals(dependentId))
          ..where((r) => r.status.equals('pending')))
        .watch();
  }

  /// Verify linking code and activate relationship
  /// For MVP, uses hardcoded code: 12345
  Future<bool> verifyLinkingCode(String relationshipId, String code) async {
    final relationship = await getRelationshipById(relationshipId);
    if (relationship == null) return false;

    // For MVP, accept hardcoded code
    if (code != AuthService.mvpLinkingCode) {
      // Increment verification attempts
      await (_db.update(_db.careRelationships)
            ..where((r) => r.id.equals(relationshipId)))
          .write(
        CareRelationshipsCompanion(
          verificationAttempts: Value(relationship.verificationAttempts + 1),
        ),
      );
      return false;
    }

    // Activate the relationship
    await (_db.update(_db.careRelationships)
          ..where((r) => r.id.equals(relationshipId)))
        .write(
      CareRelationshipsCompanion(
        status: const Value('active'),
        linkingCode: const Value(null),
        codeExpiresAt: const Value(null),
        verifiedAt: Value(DateTime.now()),
      ),
    );

    return true;
  }

  /// Get linking code for a pending relationship
  Future<String?> getLinkingCode(String relationshipId) async {
    final relationship = await getRelationshipById(relationshipId);
    return relationship?.linkingCode;
  }

  /// Cancel a pending relationship
  Future<int> cancelPendingRelationship(String relationshipId) {
    return (_db.delete(_db.careRelationships)
          ..where((r) => r.id.equals(relationshipId))
          ..where((r) => r.status.equals('pending')))
        .go();
  }

  /// Check if a pending relationship already exists between caregiver and dependent
  Future<bool> pendingRelationshipExists(
      String caregiverId, String dependentId) async {
    final relationship = await (_db.select(_db.careRelationships)
          ..where((r) => r.caregiverId.equals(caregiverId))
          ..where((r) => r.dependentId.equals(dependentId))
          ..where((r) => r.status.equals('pending')))
        .getSingleOrNull();
    return relationship != null;
  }

  /// Get all relationships (active and pending) for a caregiver
  Future<List<CareRelationship>> getAllRelationshipsForCaregiver(
      String caregiverId) {
    return (_db.select(_db.careRelationships)
          ..where((r) => r.caregiverId.equals(caregiverId)))
        .get();
  }

  /// Get all relationships (active and pending) for a dependent
  Future<List<CareRelationship>> getAllRelationshipsForDependent(
      String dependentId) {
    return (_db.select(_db.careRelationships)
          ..where((r) => r.dependentId.equals(dependentId)))
        .get();
  }

  /// Regenerate linking code for a pending relationship
  Future<String> regenerateLinkingCode(String relationshipId) async {
    final linkingCode = AuthService.mvpLinkingCode; // Use hardcoded for MVP
    final codeExpiry = _authService.getLinkingCodeExpiry();

    await (_db.update(_db.careRelationships)
          ..where((r) => r.id.equals(relationshipId)))
        .write(
      CareRelationshipsCompanion(
        linkingCode: Value(linkingCode),
        codeExpiresAt: Value(codeExpiry),
        verificationAttempts: const Value(0),
      ),
    );

    return linkingCode;
  }
}
