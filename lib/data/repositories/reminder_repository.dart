import 'package:drift/drift.dart';
import '../datasources/local/database.dart';

/// Repository for reminder-related database operations
class ReminderRepository {
  final AppDatabase _db;

  ReminderRepository(this._db);

  // ==================== Reminder Template Operations ====================

  /// Get all reminders for a dependent
  Future<List<Reminder>> getRemindersForDependent(String dependentId) {
    return (_db.select(_db.reminders)
          ..where((r) => r.dependentId.equals(dependentId))
          ..where((r) => r.isActive.equals(true))
          ..orderBy([(r) => OrderingTerm.asc(r.hour)]))
        .get();
  }

  /// Get reminder by ID
  Future<Reminder?> getReminderById(String id) {
    return (_db.select(_db.reminders)..where((r) => r.id.equals(id)))
        .getSingleOrNull();
  }

  /// Create a new reminder
  Future<void> createReminder({
    required String id,
    required String creatorId,
    required String dependentId,
    required String title,
    String? description,
    String? voiceNotePath,
    required String repeatPattern,
    String? repeatDays,
    required int hour,
    required int minute,
    String priority = 'normal',
    required DateTime startDate,
    DateTime? endDate,
  }) {
    return _db.into(_db.reminders).insert(
          RemindersCompanion.insert(
            id: id,
            creatorId: creatorId,
            dependentId: dependentId,
            title: title,
            description: Value(description),
            voiceNotePath: Value(voiceNotePath),
            repeatPattern: repeatPattern,
            repeatDays: Value(repeatDays),
            hour: hour,
            minute: minute,
            priority: Value(priority),
            startDate: startDate,
            endDate: Value(endDate),
          ),
        );
  }

  /// Update a reminder
  Future<bool> updateReminder(String id, RemindersCompanion reminder) {
    return (_db.update(_db.reminders)..where((r) => r.id.equals(id)))
        .write(reminder.copyWith(updatedAt: Value(DateTime.now())))
        .then((rows) => rows > 0);
  }

  /// Delete a reminder (soft delete by setting isActive to false)
  Future<bool> deleteReminder(String id) {
    return updateReminder(
      id,
      const RemindersCompanion(isActive: Value(false)),
    );
  }

  /// Permanently delete a reminder
  Future<int> hardDeleteReminder(String id) {
    return (_db.delete(_db.reminders)..where((r) => r.id.equals(id))).go();
  }

  /// Watch reminders for a dependent
  Stream<List<Reminder>> watchRemindersForDependent(String dependentId) {
    return (_db.select(_db.reminders)
          ..where((r) => r.dependentId.equals(dependentId))
          ..where((r) => r.isActive.equals(true))
          ..orderBy([(r) => OrderingTerm.asc(r.hour)]))
        .watch();
  }

  // ==================== Reminder Instance Operations ====================

  /// Get instances for a reminder
  Future<List<ReminderInstance>> getInstancesForReminder(String reminderId) {
    return (_db.select(_db.reminderInstances)
          ..where((ri) => ri.reminderId.equals(reminderId))
          ..orderBy([(ri) => OrderingTerm.desc(ri.scheduledTime)]))
        .get();
  }

  /// Get pending instances for a dependent
  Future<List<ReminderInstance>> getPendingInstancesForDependent(
      String dependentId) async {
    final reminders = await getRemindersForDependent(dependentId);
    if (reminders.isEmpty) return [];

    final reminderIds = reminders.map((r) => r.id).toList();

    return (_db.select(_db.reminderInstances)
          ..where((ri) => ri.reminderId.isIn(reminderIds))
          ..where((ri) => ri.status.equals('pending'))
          ..orderBy([(ri) => OrderingTerm.asc(ri.scheduledTime)]))
        .get();
  }

  /// Get today's instances for a dependent
  Future<List<ReminderInstance>> getTodayInstancesForDependent(
      String dependentId) async {
    final reminders = await getRemindersForDependent(dependentId);
    if (reminders.isEmpty) return [];

    final reminderIds = reminders.map((r) => r.id).toList();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return (_db.select(_db.reminderInstances)
          ..where((ri) => ri.reminderId.isIn(reminderIds))
          ..where((ri) => ri.scheduledTime.isBiggerOrEqualValue(startOfDay))
          ..where((ri) => ri.scheduledTime.isSmallerThanValue(endOfDay))
          ..orderBy([(ri) => OrderingTerm.asc(ri.scheduledTime)]))
        .get();
  }

  /// Create a reminder instance
  Future<void> createInstance({
    required String id,
    required String reminderId,
    required DateTime scheduledTime,
  }) {
    return _db.into(_db.reminderInstances).insert(
          ReminderInstancesCompanion.insert(
            id: id,
            reminderId: reminderId,
            scheduledTime: scheduledTime,
          ),
        );
  }

  /// Mark instance as completed
  Future<bool> markInstanceCompleted(String id) {
    return (_db.update(_db.reminderInstances)..where((ri) => ri.id.equals(id)))
        .write(ReminderInstancesCompanion(
          status: const Value('completed'),
          completedAt: Value(DateTime.now()),
        ))
        .then((rows) => rows > 0);
  }

  /// Mark instance as missed
  Future<bool> markInstanceMissed(String id) {
    return (_db.update(_db.reminderInstances)..where((ri) => ri.id.equals(id)))
        .write(const ReminderInstancesCompanion(
          status: Value('missed'),
        ))
        .then((rows) => rows > 0);
  }

  /// Snooze an instance
  Future<bool> snoozeInstance(String id, DateTime snoozeUntil) {
    return (_db.update(_db.reminderInstances)..where((ri) => ri.id.equals(id)))
        .write(ReminderInstancesCompanion(
          status: const Value('snoozed'),
          snoozedUntil: Value(snoozeUntil),
        ))
        .then((rows) => rows > 0);
  }

  /// Update escalation level
  Future<bool> updateEscalationLevel(String id, int level) {
    return (_db.update(_db.reminderInstances)..where((ri) => ri.id.equals(id)))
        .write(ReminderInstancesCompanion(
          escalationLevel: Value(level),
        ))
        .then((rows) => rows > 0);
  }

  /// Watch today's instances for a dependent
  Stream<List<ReminderInstance>> watchTodayInstancesForDependent(
      String dependentId) {
    return watchRemindersForDependent(dependentId).asyncMap((reminders) async {
      if (reminders.isEmpty) return <ReminderInstance>[];

      final reminderIds = reminders.map((r) => r.id).toList();
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      return (_db.select(_db.reminderInstances)
            ..where((ri) => ri.reminderId.isIn(reminderIds))
            ..where((ri) => ri.scheduledTime.isBiggerOrEqualValue(startOfDay))
            ..where((ri) => ri.scheduledTime.isSmallerThanValue(endOfDay))
            ..orderBy([(ri) => OrderingTerm.asc(ri.scheduledTime)]))
          .get();
    });
  }

  /// Get reminder with its instances
  Future<ReminderWithInstances?> getReminderWithInstances(String id) async {
    final reminder = await getReminderById(id);
    if (reminder == null) return null;

    final instances = await getInstancesForReminder(id);
    return ReminderWithInstances(reminder: reminder, instances: instances);
  }
}

/// Data class combining a reminder with its instances
class ReminderWithInstances {
  final Reminder reminder;
  final List<ReminderInstance> instances;

  ReminderWithInstances({
    required this.reminder,
    required this.instances,
  });
}
