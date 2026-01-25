import 'package:drift/drift.dart';
import '../datasources/local/database.dart';

/// Repository for user-related database operations
class UserRepository {
  final AppDatabase _db;

  UserRepository(this._db);

  /// Get all users
  Future<List<User>> getAllUsers() {
    return _db.select(_db.users).get();
  }

  /// Get user by ID
  Future<User?> getUserById(String id) {
    return (_db.select(_db.users)..where((u) => u.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get users by role
  Future<List<User>> getUsersByRole(String role) {
    return (_db.select(_db.users)..where((u) => u.role.equals(role))).get();
  }

  /// Get the current user (first user in database for local-first MVP)
  Future<User?> getCurrentUser() {
    return (_db.select(_db.users)..limit(1)).getSingleOrNull();
  }

  /// Create or update a user
  Future<void> upsertUser(UsersCompanion user) {
    return _db.into(_db.users).insertOnConflictUpdate(user);
  }

  /// Create a new user
  Future<void> createUser({
    required String id,
    required String name,
    required String role,
    String? avatarPath,
  }) {
    return _db.into(_db.users).insert(
          UsersCompanion.insert(
            id: id,
            name: name,
            role: role,
            avatarPath: Value(avatarPath),
          ),
        );
  }

  /// Update user
  Future<bool> updateUser(String id, UsersCompanion user) {
    return (_db.update(_db.users)..where((u) => u.id.equals(id)))
        .write(user)
        .then((rows) => rows > 0);
  }

  /// Delete user
  Future<int> deleteUser(String id) {
    return (_db.delete(_db.users)..where((u) => u.id.equals(id))).go();
  }

  /// Watch all users (stream for reactive updates)
  Stream<List<User>> watchAllUsers() {
    return _db.select(_db.users).watch();
  }

  /// Watch user by ID
  Stream<User?> watchUserById(String id) {
    return (_db.select(_db.users)..where((u) => u.id.equals(id)))
        .watchSingleOrNull();
  }

  /// Get all dependents for a caregiver
  Future<List<User>> getDependentsForCaregiver(String caregiverId) async {
    final relationships = await (_db.select(_db.careRelationships)
          ..where((r) => r.caregiverId.equals(caregiverId))
          ..where((r) => r.status.equals('active')))
        .get();

    if (relationships.isEmpty) return [];

    final dependentIds = relationships.map((r) => r.dependentId).toList();

    return (_db.select(_db.users)
          ..where((u) => u.id.isIn(dependentIds)))
        .get();
  }

  /// Watch dependents for a caregiver
  Stream<List<User>> watchDependentsForCaregiver(String caregiverId) {
    return (_db.select(_db.careRelationships)
          ..where((r) => r.caregiverId.equals(caregiverId))
          ..where((r) => r.status.equals('active')))
        .watch()
        .asyncMap((relationships) async {
      if (relationships.isEmpty) return <User>[];

      final dependentIds = relationships.map((r) => r.dependentId).toList();

      return (_db.select(_db.users)
            ..where((u) => u.id.isIn(dependentIds)))
          .get();
    });
  }
}
