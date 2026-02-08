import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

/// User profile table
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get firstName => text()();
  TextColumn get lastName => text().nullable()();
  TextColumn get role => text()(); // 'caregiver' or 'dependent'
  TextColumn get avatarPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  // Authentication fields
  TextColumn get email => text()();
  TextColumn get passwordHash => text()();
  TextColumn get phoneNumber => text().nullable()();
  TextColumn get uniqueCode => text()(); // 9-digit alphanumeric (e.g., "A1B2C3D4E")
  BoolColumn get emailVerified =>
      boolean().withDefault(const Constant(false))();
  TextColumn get verificationCode => text().nullable()(); // Temp code for email verification
  DateTimeColumn get verificationCodeExpiry => dateTime().nullable()();
  DateTimeColumn get lastLoginAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Care relationship between caregiver and dependent
class CareRelationships extends Table {
  TextColumn get id => text()();
  TextColumn get caregiverId => text().references(Users, #id)();
  TextColumn get dependentId => text().references(Users, #id)();
  TextColumn get status =>
      text().withDefault(const Constant('pending'))(); // active, pending
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Linking verification fields
  TextColumn get linkingCode => text().nullable()(); // 5-digit verification (e.g., "12345")
  DateTimeColumn get codeExpiresAt => dateTime().nullable()();
  IntColumn get verificationAttempts =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get verifiedAt => dateTime().nullable()();
  TextColumn get initiatedBy => text()(); // 'caregiver' or 'dependent'

  @override
  Set<Column> get primaryKey => {id};
}

/// Reminders table - the template for recurring reminders
class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get creatorId => text().references(Users, #id)();
  TextColumn get dependentId => text().references(Users, #id)();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  TextColumn get voiceNotePath => text().nullable()();
  TextColumn get repeatPattern =>
      text()(); // 'once', 'daily', 'weekly', 'specific_days'
  TextColumn get repeatDays =>
      text().nullable()(); // JSON array for specific days e.g. ['mon','wed','fri']
  IntColumn get hour => integer()();
  IntColumn get minute => integer()();
  TextColumn get priority =>
      text().withDefault(const Constant('normal'))(); // 'normal', 'high'
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Reminder instances - individual occurrences of reminders
class ReminderInstances extends Table {
  TextColumn get id => text()();
  TextColumn get reminderId => text().references(Reminders, #id)();
  DateTimeColumn get scheduledTime => dateTime()();
  TextColumn get status => text().withDefault(
      const Constant('pending'))(); // 'pending', 'completed', 'missed', 'snoozed'
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get snoozedUntil => dateTime().nullable()();
  IntColumn get escalationLevel =>
      integer().withDefault(const Constant(0))(); // 0=gentle, 1=repeat, 2=fullscreen
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// SOS events triggered by dependents
class SosEvents extends Table {
  TextColumn get id => text()();
  TextColumn get dependentId => text().references(Users, #id)();
  TextColumn get status => text().withDefault(
      const Constant('triggered'))(); // 'triggered', 'cancelled', 'resolved'
  DateTimeColumn get triggeredAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  TextColumn get resolvedBy => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Emergency contacts for dependents
class EmergencyContacts extends Table {
  TextColumn get id => text()();
  TextColumn get dependentId => text().references(Users, #id)();
  TextColumn get name => text()();
  TextColumn get phoneNumber => text()();
  TextColumn get relationship => text().nullable()(); // 'family', 'doctor', 'neighbor'
  IntColumn get priority => integer().withDefault(const Constant(1))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// App settings stored in database
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [
  Users,
  CareRelationships,
  Reminders,
  ReminderInstances,
  SosEvents,
  EmergencyContacts,
  AppSettings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Migration from v1 to v2: Add auth and linking fields
        if (from < 2) {
          // Add new columns to Users table with defaults for existing rows
          await customStatement(
            'ALTER TABLE users ADD COLUMN email TEXT NOT NULL DEFAULT ""',
          );
          await customStatement(
            'ALTER TABLE users ADD COLUMN password_hash TEXT NOT NULL DEFAULT ""',
          );
          await customStatement(
            'ALTER TABLE users ADD COLUMN phone_number TEXT',
          );
          await customStatement(
            'ALTER TABLE users ADD COLUMN unique_code TEXT NOT NULL DEFAULT ""',
          );
          await customStatement(
            'ALTER TABLE users ADD COLUMN email_verified INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            'ALTER TABLE users ADD COLUMN verification_code TEXT',
          );
          await customStatement(
            'ALTER TABLE users ADD COLUMN verification_code_expiry INTEGER',
          );
          await customStatement(
            'ALTER TABLE users ADD COLUMN last_login_at INTEGER',
          );

          // Update existing users with generated values
          final existingUsers = await select(users).get();
          for (final user in existingUsers) {
            final uniqueCode = _generateMigrationCode();
            await customStatement(
              'UPDATE users SET email = ?, unique_code = ?, email_verified = 1 WHERE id = ?',
              ['${user.id}@migrated.local', uniqueCode, user.id],
            );
          }

          // Add new columns to CareRelationships table
          await customStatement(
            'ALTER TABLE care_relationships ADD COLUMN linking_code TEXT',
          );
          await customStatement(
            'ALTER TABLE care_relationships ADD COLUMN code_expires_at INTEGER',
          );
          await customStatement(
            'ALTER TABLE care_relationships ADD COLUMN verification_attempts INTEGER NOT NULL DEFAULT 0',
          );
          await customStatement(
            'ALTER TABLE care_relationships ADD COLUMN verified_at INTEGER',
          );
          await customStatement(
            'ALTER TABLE care_relationships ADD COLUMN initiated_by TEXT NOT NULL DEFAULT "caregiver"',
          );
        }

        // Migration from v2 to v3: Split name into first/last name
        if (from < 3) {
          final columns = await customSelect('PRAGMA table_info(users)').get();
          final columnNames = columns
              .map((row) => row.data['name'] as String?)
              .whereType<String>()
              .toSet();

          if (columnNames.contains('name')) {
            await customStatement(
              'ALTER TABLE users RENAME COLUMN name TO first_name',
            );
          }

          if (!columnNames.contains('last_name')) {
            await customStatement('ALTER TABLE users ADD COLUMN last_name TEXT');
          }

          await customStatement('''
            UPDATE users
            SET first_name = CASE
                  WHEN instr(first_name, ' ') > 0 THEN substr(first_name, 1, instr(first_name, ' ') - 1)
                  ELSE first_name
                END,
                last_name = CASE
                  WHEN instr(first_name, ' ') > 0 THEN trim(substr(first_name, instr(first_name, ' ') + 1))
                  ELSE last_name
                END
          ''');
        }
      },
    );
  }

  /// Generate a simple unique code for migration
  static String _generateMigrationCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer();
    for (var i = 0; i < 9; i++) {
      buffer.write(chars[(random + i * 7) % chars.length]);
    }
    return buffer.toString();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'parental_care.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
