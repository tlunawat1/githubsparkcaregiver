import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

/// User profile table
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get role => text()(); // 'caregiver' or 'dependent'
  TextColumn get avatarPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Care relationship between caregiver and dependent
class CareRelationships extends Table {
  TextColumn get id => text()();
  TextColumn get caregiverId => text().references(Users, #id)();
  TextColumn get dependentId => text().references(Users, #id)();
  TextColumn get status =>
      text().withDefault(const Constant('active'))(); // active, pending
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Handle future migrations here
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'parental_care.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
