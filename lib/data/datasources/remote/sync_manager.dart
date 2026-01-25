import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'auth_api.dart';
import 'user_api.dart';
import 'relationship_api.dart';
import 'reminder_api.dart';
import 'sos_api.dart';
import 'signalr_service.dart';

/// Sync operation type
enum SyncOperationType {
  create,
  update,
  delete,
}

/// Pending sync operation
class SyncOperation {
  final String id;
  final String entityType;
  final String entityId;
  final SyncOperationType operationType;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  int retryCount;

  SyncOperation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operationType,
    required this.data,
    DateTime? createdAt,
    this.retryCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'entityType': entityType,
        'entityId': entityId,
        'operationType': operationType.name,
        'data': data,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      id: json['id'] as String,
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String,
      operationType: SyncOperationType.values.firstWhere(
        (e) => e.name == json['operationType'],
      ),
      data: json['data'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }
}

/// Sync status
enum SyncStatus {
  idle,
  syncing,
  error,
  offline,
}

/// Manages synchronization between local and remote data
class SyncManager {
  final ApiClient _apiClient;
  final AuthApi _authApi;
  final UserApi _userApi;
  final RelationshipApi _relationshipApi;
  final ReminderApi _reminderApi;
  final SosApi _sosApi;
  final SignalRService _signalRService;

  // Sync state
  SyncStatus _status = SyncStatus.idle;
  final Queue<SyncOperation> _pendingOperations = Queue();
  Timer? _syncTimer;
  bool _isOnline = true;

  // Stream controllers
  final _statusController = StreamController<SyncStatus>.broadcast();
  final _pendingCountController = StreamController<int>.broadcast();

  // Public streams
  Stream<SyncStatus> get status => _statusController.stream;
  Stream<int> get pendingCount => _pendingCountController.stream;

  SyncStatus get currentStatus => _status;
  int get pendingOperationsCount => _pendingOperations.length;
  bool get isOnline => _isOnline;

  // Callbacks
  Function(String entityType, String entityId, Map<String, dynamic> data)?
      onRemoteUpdate;
  Function(String error)? onSyncError;

  SyncManager({
    required ApiClient apiClient,
    required AuthApi authApi,
    required UserApi userApi,
    required RelationshipApi relationshipApi,
    required ReminderApi reminderApi,
    required SosApi sosApi,
    required SignalRService signalRService,
  })  : _apiClient = apiClient,
        _authApi = authApi,
        _userApi = userApi,
        _relationshipApi = relationshipApi,
        _reminderApi = reminderApi,
        _sosApi = sosApi,
        _signalRService = signalRService {
    _setupSignalRListeners();
  }

  /// Initialize sync manager
  Future<void> initialize() async {
    await _apiClient.initialize();

    // Listen to SignalR connection state
    _signalRService.connectionState.listen((state) {
      _isOnline = state == SignalRConnectionState.connected;
      if (_isOnline && _pendingOperations.isNotEmpty) {
        _processPendingOperations();
      }
    });

    // Start periodic sync check
    _startPeriodicSync();
  }

  /// Set online/offline status
  void setOnlineStatus(bool isOnline) {
    _isOnline = isOnline;
    _updateStatus(isOnline ? SyncStatus.idle : SyncStatus.offline);

    if (isOnline && _pendingOperations.isNotEmpty) {
      _processPendingOperations();
    }
  }

  /// Queue an operation for sync
  void queueOperation(SyncOperation operation) {
    _pendingOperations.add(operation);
    _pendingCountController.add(_pendingOperations.length);

    if (_isOnline) {
      _processPendingOperations();
    }
  }

  /// Force sync all pending operations
  Future<void> forcSync() async {
    if (!_isOnline) {
      _updateStatus(SyncStatus.offline);
      return;
    }

    await _processPendingOperations();
  }

  /// Process pending operations
  Future<void> _processPendingOperations() async {
    if (_status == SyncStatus.syncing || _pendingOperations.isEmpty) {
      return;
    }

    _updateStatus(SyncStatus.syncing);

    while (_pendingOperations.isNotEmpty && _isOnline) {
      final operation = _pendingOperations.first;

      try {
        await _executeOperation(operation);
        _pendingOperations.removeFirst();
        _pendingCountController.add(_pendingOperations.length);
      } catch (e) {
        operation.retryCount++;

        if (operation.retryCount >= 3) {
          // Move to dead letter queue or notify user
          _pendingOperations.removeFirst();
          onSyncError?.call('Failed to sync ${operation.entityType}: $e');
        } else {
          // Move to end of queue for retry
          _pendingOperations.removeFirst();
          _pendingOperations.add(operation);
        }

        _updateStatus(SyncStatus.error);
        break;
      }
    }

    if (_pendingOperations.isEmpty) {
      _updateStatus(SyncStatus.idle);
    }
  }

  /// Execute a single sync operation
  Future<void> _executeOperation(SyncOperation operation) async {
    switch (operation.entityType) {
      case 'reminder':
        await _syncReminder(operation);
        break;
      case 'relationship':
        await _syncRelationship(operation);
        break;
      case 'sos':
        await _syncSos(operation);
        break;
      case 'user':
        await _syncUser(operation);
        break;
      default:
        debugPrint('Unknown entity type: ${operation.entityType}');
    }
  }

  /// Sync reminder operation
  Future<void> _syncReminder(SyncOperation operation) async {
    switch (operation.operationType) {
      case SyncOperationType.create:
        await _reminderApi.createReminder(
          dependentId: operation.data['dependentId'] as String,
          title: operation.data['title'] as String,
          description: operation.data['description'] as String?,
          voiceNoteUrl: operation.data['voiceNoteUrl'] as String?,
          repeatPattern: operation.data['repeatPattern'] as String,
          repeatDays: operation.data['repeatDays'] as String?,
          hour: operation.data['hour'] as int,
          minute: operation.data['minute'] as int,
          priority: operation.data['priority'] as String? ?? 'normal',
        );
        break;
      case SyncOperationType.update:
        await _reminderApi.updateReminder(
          id: operation.entityId,
          title: operation.data['title'] as String?,
          description: operation.data['description'] as String?,
          voiceNoteUrl: operation.data['voiceNoteUrl'] as String?,
          repeatPattern: operation.data['repeatPattern'] as String?,
          repeatDays: operation.data['repeatDays'] as String?,
          hour: operation.data['hour'] as int?,
          minute: operation.data['minute'] as int?,
          priority: operation.data['priority'] as String?,
          isActive: operation.data['isActive'] as bool?,
        );
        break;
      case SyncOperationType.delete:
        await _reminderApi.deleteReminder(operation.entityId);
        break;
    }
  }

  /// Sync relationship operation
  Future<void> _syncRelationship(SyncOperation operation) async {
    switch (operation.operationType) {
      case SyncOperationType.create:
        await _relationshipApi.createRelationship(
          targetUserIdentifier: operation.data['targetUserIdentifier'] as String,
          initiatedBy: operation.data['initiatedBy'] as String,
        );
        break;
      case SyncOperationType.delete:
        await _relationshipApi.deleteRelationship(operation.entityId);
        break;
      default:
        break;
    }
  }

  /// Sync SOS operation
  Future<void> _syncSos(SyncOperation operation) async {
    switch (operation.operationType) {
      case SyncOperationType.create:
        await _sosApi.triggerSos(
          notes: operation.data['notes'] as String?,
        );
        break;
      case SyncOperationType.update:
        final status = operation.data['status'] as String?;
        if (status == 'resolved') {
          await _sosApi.resolveSos(
            id: operation.entityId,
            notes: operation.data['notes'] as String?,
          );
        } else if (status == 'cancelled') {
          await _sosApi.cancelSos(operation.entityId);
        }
        break;
      default:
        break;
    }
  }

  /// Sync user operation
  Future<void> _syncUser(SyncOperation operation) async {
    if (operation.operationType == SyncOperationType.update) {
      await _userApi.updateCurrentUser(
        name: operation.data['name'] as String?,
        phoneNumber: operation.data['phoneNumber'] as String?,
        avatarUrl: operation.data['avatarUrl'] as String?,
      );
    }
  }

  /// Setup SignalR event listeners
  void _setupSignalRListeners() {
    _signalRService.events.listen((event) {
      String? entityType;
      String? entityId;
      Map<String, dynamic> data = event.data;

      switch (event.type) {
        case SignalREventType.reminderCreated:
        case SignalREventType.reminderUpdated:
        case SignalREventType.reminderDeleted:
          entityType = 'reminder';
          entityId = data['id'] as String?;
          break;
        case SignalREventType.linkRequestReceived:
        case SignalREventType.linkVerified:
        case SignalREventType.linkRemoved:
          entityType = 'relationship';
          entityId = data['relationshipId'] as String?;
          break;
        case SignalREventType.sosTriggered:
        case SignalREventType.sosResolved:
        case SignalREventType.sosCancelled:
          entityType = 'sos';
          entityId = data['sosEventId'] as String?;
          break;
        default:
          return;
      }

      if (entityType != null && entityId != null) {
        onRemoteUpdate?.call(entityType, entityId, data);
      }
    });
  }

  /// Start periodic sync
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isOnline && _pendingOperations.isNotEmpty) {
        _processPendingOperations();
      }
    });
  }

  /// Update sync status
  void _updateStatus(SyncStatus status) {
    _status = status;
    _statusController.add(status);
  }

  /// Clear all pending operations
  void clearPendingOperations() {
    _pendingOperations.clear();
    _pendingCountController.add(0);
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _statusController.close();
    _pendingCountController.close();
  }
}
