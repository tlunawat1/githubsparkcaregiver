import 'package:drift/drift.dart';
import '../datasources/local/database.dart';

/// Repository for SOS event-related database operations
class SosRepository {
  final AppDatabase _db;

  SosRepository(this._db);

  /// Get all SOS events for a dependent
  Future<List<SosEvent>> getSosEventsForDependent(String dependentId) {
    return (_db.select(_db.sosEvents)
          ..where((s) => s.dependentId.equals(dependentId))
          ..orderBy([(s) => OrderingTerm.desc(s.triggeredAt)]))
        .get();
  }

  /// Get recent SOS events (last 24 hours)
  Future<List<SosEvent>> getRecentSosEvents(String dependentId) {
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));

    return (_db.select(_db.sosEvents)
          ..where((s) => s.dependentId.equals(dependentId))
          ..where((s) => s.triggeredAt.isBiggerOrEqualValue(yesterday))
          ..orderBy([(s) => OrderingTerm.desc(s.triggeredAt)]))
        .get();
  }

  /// Get active (unresolved) SOS event
  Future<SosEvent?> getActiveSosEvent(String dependentId) {
    return (_db.select(_db.sosEvents)
          ..where((s) => s.dependentId.equals(dependentId))
          ..where((s) => s.status.equals('triggered'))
          ..orderBy([(s) => OrderingTerm.desc(s.triggeredAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Create a new SOS event
  Future<void> createSosEvent({
    required String id,
    required String dependentId,
  }) {
    return _db.into(_db.sosEvents).insert(
          SosEventsCompanion.insert(
            id: id,
            dependentId: dependentId,
            triggeredAt: DateTime.now(),
          ),
        );
  }

  /// Cancel an SOS event
  Future<bool> cancelSosEvent(String id) {
    return (_db.update(_db.sosEvents)..where((s) => s.id.equals(id)))
        .write(SosEventsCompanion(
          status: const Value('cancelled'),
          resolvedAt: Value(DateTime.now()),
        ))
        .then((rows) => rows > 0);
  }

  /// Resolve an SOS event
  Future<bool> resolveSosEvent(String id, String resolvedBy, {String? notes}) {
    return (_db.update(_db.sosEvents)..where((s) => s.id.equals(id)))
        .write(SosEventsCompanion(
          status: const Value('resolved'),
          resolvedAt: Value(DateTime.now()),
          resolvedBy: Value(resolvedBy),
          notes: Value(notes),
        ))
        .then((rows) => rows > 0);
  }

  /// Watch SOS events for a dependent
  Stream<List<SosEvent>> watchSosEventsForDependent(String dependentId) {
    return (_db.select(_db.sosEvents)
          ..where((s) => s.dependentId.equals(dependentId))
          ..orderBy([(s) => OrderingTerm.desc(s.triggeredAt)]))
        .watch();
  }

  /// Watch for active SOS event
  Stream<SosEvent?> watchActiveSosEvent(String dependentId) {
    return (_db.select(_db.sosEvents)
          ..where((s) => s.dependentId.equals(dependentId))
          ..where((s) => s.status.equals('triggered'))
          ..orderBy([(s) => OrderingTerm.desc(s.triggeredAt)])
          ..limit(1))
        .watchSingleOrNull();
  }
}
