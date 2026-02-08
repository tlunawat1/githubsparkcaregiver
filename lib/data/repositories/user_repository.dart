import 'package:drift/drift.dart';
import '../datasources/local/database.dart';
import '../../features/auth/domain/auth_service.dart';

/// Repository for user-related database operations
class UserRepository {
  final AppDatabase _db;
  final AuthService _authService = AuthService();

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

  /// Create a new user (for backward compatibility)
  /// For full authentication, use createUserWithCredentials instead
  Future<void> createUser({
    required String id,
    required String firstName,
    String? lastName,
    required String role,
    String? avatarPath,
    String? email,
    String? password,
  }) {
    // Generate required fields if not provided
    final uniqueCode = _authService.generateUniqueCode();
    final passwordHash = password != null
        ? _authService.hashPassword(password)
        : _authService.hashPassword('default123'); // Default for legacy users

    return _db.into(_db.users).insert(
          UsersCompanion.insert(
            id: id,
            firstName: firstName,
            lastName: Value(lastName),
            role: role,
            email: email ?? '$id@placeholder.local',
            passwordHash: passwordHash,
            uniqueCode: uniqueCode,
            avatarPath: Value(avatarPath),
            emailVerified: const Value(true), // Auto-verify for legacy users
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

  // ============================================
  // Authentication Methods
  // ============================================

  /// Create a new user with credentials
  Future<User> createUserWithCredentials({
    required String id,
    required String firstName,
    String? lastName,
    required String email,
    required String password,
    required String role,
    String? phoneNumber,
  }) async {
    final passwordHash = _authService.hashPassword(password);
    final uniqueCode = _authService.generateUniqueCode();
    final verificationCode = AuthService.mvpEmailVerificationCode; // Use hardcoded for MVP
    final verificationExpiry = _authService.getVerificationCodeExpiry();

    await _db.into(_db.users).insert(
          UsersCompanion.insert(
            id: id,
            firstName: firstName,
            lastName: Value(lastName),
            email: email,
            passwordHash: passwordHash,
            role: role,
            uniqueCode: uniqueCode,
            phoneNumber: Value(phoneNumber),
            emailVerified: const Value(false),
            verificationCode: Value(verificationCode),
            verificationCodeExpiry: Value(verificationExpiry),
          ),
        );

    return (await getUserById(id))!;
  }

  /// Authenticate user with email and password
  /// Returns the user if authentication succeeds, null otherwise
  Future<User?> authenticateWithEmail(String email, String password) async {
    final user = await getUserByEmail(email);
    if (user == null) return null;

    if (!_authService.verifyPassword(password, user.passwordHash)) {
      return null;
    }

    // Update last login time
    await updateLastLogin(user.id);

    return user;
  }

  /// Authenticate user with email and verification code (login via code)
  /// For MVP, uses hardcoded code: 123456
  Future<User?> authenticateWithCode(String email, String code) async {
    final user = await getUserByEmail(email);
    if (user == null) return null;

    // For MVP, accept hardcoded code
    if (code != AuthService.mvpLoginCode) {
      return null;
    }

    // Update last login time
    await updateLastLogin(user.id);

    return user;
  }

  /// Get user by email
  Future<User?> getUserByEmail(String email) {
    return (_db.select(_db.users)
          ..where((u) => u.email.equals(email.toLowerCase())))
        .getSingleOrNull();
  }

  /// Get user by unique code
  Future<User?> getUserByUniqueCode(String uniqueCode) {
    return (_db.select(_db.users)
          ..where((u) => u.uniqueCode.equals(uniqueCode.toUpperCase())))
        .getSingleOrNull();
  }

  /// Verify user's email with verification code
  /// For MVP, uses hardcoded code: 123456
  Future<bool> verifyEmail(String userId, String code) async {
    final user = await getUserById(userId);
    if (user == null) return false;

    // For MVP, accept hardcoded code
    if (code != AuthService.mvpEmailVerificationCode) {
      return false;
    }

    // Mark email as verified and clear verification code
    await (_db.update(_db.users)..where((u) => u.id.equals(userId))).write(
      UsersCompanion(
        emailVerified: const Value(true),
        verificationCode: const Value(null),
        verificationCodeExpiry: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );

    return true;
  }

  /// Update user's last login timestamp
  Future<void> updateLastLogin(String userId) async {
    await (_db.update(_db.users)..where((u) => u.id.equals(userId))).write(
      UsersCompanion(
        lastLoginAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Check if email is already registered
  Future<bool> isEmailRegistered(String email) async {
    final user = await getUserByEmail(email);
    return user != null;
  }

  /// Check if unique code exists
  Future<bool> isUniqueCodeExists(String uniqueCode) async {
    final user = await getUserByUniqueCode(uniqueCode);
    return user != null;
  }

  /// Resend verification code (for MVP, just returns the hardcoded code)
  Future<String> resendVerificationCode(String userId) async {
    final verificationCode = AuthService.mvpEmailVerificationCode;
    final verificationExpiry = _authService.getVerificationCodeExpiry();

    await (_db.update(_db.users)..where((u) => u.id.equals(userId))).write(
      UsersCompanion(
        verificationCode: Value(verificationCode),
        verificationCodeExpiry: Value(verificationExpiry),
        updatedAt: Value(DateTime.now()),
      ),
    );

    return verificationCode;
  }
}
