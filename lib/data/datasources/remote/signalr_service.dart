import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

/// SignalR connection state
enum SignalRConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Real-time event types
enum SignalREventType {
  linkRequestReceived,
  linkVerified,
  linkRemoved,
  sosTriggered,
  sosResolved,
  sosCancelled,
  reminderCreated,
  reminderUpdated,
  reminderDeleted,
  instanceCreated,
  instanceStatusChanged,
  userOnline,
  pong,
}

/// SignalR event data
class SignalREvent {
  final SignalREventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  SignalREvent({
    required this.type,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// SignalR service for real-time communication
class SignalRService {
  static const String _defaultHubUrl = 'https://remotecaregiver-api-gremgwfab5c9fbhs.canadacentral-01.azurewebsites.net/hubs/sync';
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const int _maxReconnectAttempts = 10;
  static const int _maxSubscriptionRetries = 3;

  final String hubUrl;
  HubConnection? _connection;
  String? _accessToken;
  String? _connectedWithToken; // Track which token the current connection was made with

  SignalRConnectionState _connectionState = SignalRConnectionState.disconnected;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  // Subscription tracking for restoration after reconnection
  final Set<String> _subscribedDependents = {};
  
  // Pending subscriptions that failed and need retry
  final Set<String> _pendingSubscriptions = {};

  // Stream controllers for events
  final _connectionStateController =
      StreamController<SignalRConnectionState>.broadcast();
  final _eventController = StreamController<SignalREvent>.broadcast();

  // Public streams
  Stream<SignalRConnectionState> get connectionState =>
      _connectionStateController.stream;
  Stream<SignalREvent> get events => _eventController.stream;

  SignalRConnectionState get currentState => _connectionState;
  bool get isConnected => _connectionState == SignalRConnectionState.connected;
  
  /// Get list of currently subscribed dependents (for debugging)
  Set<String> get subscribedDependents => Set.unmodifiable(_subscribedDependents);

  SignalRService({String? hubUrl}) : hubUrl = hubUrl ?? _defaultHubUrl;

  /// Set access token for authentication
  void setAccessToken(String? token) {
    _accessToken = token;
    debugPrint('SignalR: Access token set (${token != null ? 'provided' : 'null'})');
  }

  /// Connect to SignalR hub
  Future<void> connect() async {
    // If already connected, check if the access token has changed (e.g., user switched accounts)
    if (_connection != null &&
        _connectionState == SignalRConnectionState.connected) {
      if (_accessToken != null && _accessToken != _connectedWithToken) {
        debugPrint('SignalR: Access token changed while connected - reconnecting with new token');
        await disconnect(clearTracking: true);
      } else {
        return;
      }
    }

    _updateState(SignalRConnectionState.connecting);

    try {
      _connection = HubConnectionBuilder()
          .withUrl(
            hubUrl,
            options: HttpConnectionOptions(
              accessTokenFactory: () async => _accessToken ?? '',
              skipNegotiation: true,
              transport: HttpTransportType.WebSockets,
            ),
          )
          .withAutomaticReconnect()
          .build();

      // Register event handlers
      _registerEventHandlers();

      // Connection state handlers
      _connection!.onclose(({error}) {
        _updateState(SignalRConnectionState.disconnected);
        _startReconnect();
      });

      _connection!.onreconnecting(({error}) {
        _updateState(SignalRConnectionState.reconnecting);
      });

      _connection!.onreconnected(({connectionId}) {
        debugPrint('SignalR: Reconnected with connectionId: $connectionId');
        _updateState(SignalRConnectionState.connected);
        _reconnectAttempts = 0;
        _startPing();
        // Restore subscriptions after reconnection
        _restoreSubscriptions();
      });

      debugPrint('SignalR: Starting connection to $hubUrl');
      await _connection!.start();
      _connectedWithToken = _accessToken; // Track which token this connection used
      _updateState(SignalRConnectionState.connected);
      _reconnectAttempts = 0;
      _startPing();
      
      // Restore any tracked subscriptions and process pending ones
      _restoreSubscriptions();
      _processPendingSubscriptions();

      debugPrint('SignalR: Connected successfully');
    } catch (e) {
      debugPrint('SignalR connection error: $e');
      _updateState(SignalRConnectionState.disconnected);
      _startReconnect();
    }
  }

  /// Disconnect from SignalR hub
  /// Set [clearTracking] to true to also clear subscription tracking (e.g., on logout)
  Future<void> disconnect({bool clearTracking = false}) async {
    _stopPing();
    _stopReconnect();

    if (_connection != null) {
      try {
        await _connection!.stop();
      } catch (e) {
        debugPrint('SignalR disconnect error: $e');
      }
      _connection = null;
    }
    
    _connectedWithToken = null;
    
    if (clearTracking) {
      clearSubscriptions();
    }

    _updateState(SignalRConnectionState.disconnected);
  }
  
  /// Ensure connection is active, reconnect if needed
  /// Returns true if connected, false if connection failed
  Future<bool> ensureConnected() async {
    if (isConnected) {
      debugPrint('SignalR: Already connected');
      return true;
    }
    
    if (_accessToken == null || _accessToken!.isEmpty) {
      debugPrint('SignalR: Cannot connect - no access token');
      return false;
    }
    
    debugPrint('SignalR: Connection not active, attempting to connect...');
    await connect();
    
    // Wait a bit for connection to establish
    int attempts = 0;
    while (!isConnected && attempts < 10) {
      await Future.delayed(const Duration(milliseconds: 200));
      attempts++;
    }
    
    return isConnected;
  }

  /// Subscribe to updates for a specific dependent (for caregivers)
  /// Tracks the subscription for automatic restoration after reconnection
  Future<bool> subscribeToDependent(String dependentId) async {
    // Always track the subscription intent, even if not connected
    _subscribedDependents.add(dependentId);
    
    if (!isConnected) {
      // Queue for later when connected
      _pendingSubscriptions.add(dependentId);
      debugPrint('SignalR: Queued subscription to dependent: $dependentId (not connected)');
      return false;
    }

    try {
      await _connection!.invoke('SubscribeToDependent', args: [dependentId]);
      _pendingSubscriptions.remove(dependentId);
      debugPrint('SignalR: Subscribed to dependent: $dependentId');
      return true;
    } catch (e) {
      debugPrint('SignalR: Error subscribing to dependent $dependentId: $e');
      _pendingSubscriptions.add(dependentId);
      return false;
    }
  }

  /// Unsubscribe from dependent updates
  /// Removes tracking so subscription won't be restored after reconnection
  Future<void> unsubscribeFromDependent(String dependentId) async {
    // Always remove from tracking
    _subscribedDependents.remove(dependentId);
    _pendingSubscriptions.remove(dependentId);
    
    if (!isConnected) {
      debugPrint('SignalR: Removed subscription tracking for dependent: $dependentId (not connected)');
      return;
    }

    try {
      await _connection!.invoke('UnsubscribeFromDependent', args: [dependentId]);
      debugPrint('SignalR: Unsubscribed from dependent: $dependentId');
    } catch (e) {
      debugPrint('SignalR: Error unsubscribing from dependent $dependentId: $e');
    }
  }
  
  /// Restore all tracked subscriptions after reconnection
  Future<void> _restoreSubscriptions() async {
    if (_subscribedDependents.isEmpty) {
      debugPrint('SignalR: No subscriptions to restore');
      return;
    }
    
    debugPrint('SignalR: Restoring ${_subscribedDependents.length} subscriptions...');
    
    for (final dependentId in _subscribedDependents.toList()) {
      await _subscribeWithRetry(dependentId);
    }
    
    debugPrint('SignalR: Subscription restoration complete');
  }
  
  /// Process any pending subscriptions that failed earlier
  Future<void> _processPendingSubscriptions() async {
    if (_pendingSubscriptions.isEmpty) return;
    
    debugPrint('SignalR: Processing ${_pendingSubscriptions.length} pending subscriptions...');
    
    final pending = _pendingSubscriptions.toList();
    for (final dependentId in pending) {
      await _subscribeWithRetry(dependentId);
    }
  }
  
  /// Subscribe with retry logic
  Future<bool> _subscribeWithRetry(String dependentId, {int retries = 0}) async {
    if (!isConnected) return false;
    
    try {
      await _connection!.invoke('SubscribeToDependent', args: [dependentId]);
      _pendingSubscriptions.remove(dependentId);
      debugPrint('SignalR: Successfully subscribed to dependent: $dependentId');
      return true;
    } catch (e) {
      debugPrint('SignalR: Subscription attempt ${retries + 1} failed for $dependentId: $e');
      
      if (retries < _maxSubscriptionRetries) {
        await Future.delayed(Duration(milliseconds: 500 * (retries + 1)));
        return _subscribeWithRetry(dependentId, retries: retries + 1);
      }
      
      debugPrint('SignalR: Max retries reached for subscription to $dependentId');
      return false;
    }
  }
  
  /// Check if currently subscribed to a dependent
  bool isSubscribedToDependent(String dependentId) {
    return _subscribedDependents.contains(dependentId);
  }
  
  /// Clear all subscriptions (useful for logout)
  void clearSubscriptions() {
    _subscribedDependents.clear();
    _pendingSubscriptions.clear();
    debugPrint('SignalR: All subscriptions cleared');
  }

  /// Notify that user is online
  Future<void> notifyOnline() async {
    if (!isConnected) return;

    try {
      await _connection!.invoke('NotifyOnline');
    } catch (e) {
      debugPrint('Error notifying online: $e');
    }
  }

  /// Register SignalR event handlers
  void _registerEventHandlers() {
    if (_connection == null) return;

    // Link events
    _connection!.on('LinkRequestReceived', (arguments) {
      _emitEvent(SignalREventType.linkRequestReceived, arguments);
    });

    _connection!.on('LinkVerified', (arguments) {
      _emitEvent(SignalREventType.linkVerified, arguments);
    });

    _connection!.on('LinkRemoved', (arguments) {
      _emitEvent(SignalREventType.linkRemoved, arguments);
    });

    // SOS events
    _connection!.on('SosTriggered', (arguments) {
      _emitEvent(SignalREventType.sosTriggered, arguments);
    });

    _connection!.on('SosResolved', (arguments) {
      _emitEvent(SignalREventType.sosResolved, arguments);
    });

    _connection!.on('SosCancelled', (arguments) {
      _emitEvent(SignalREventType.sosCancelled, arguments);
    });

    // Reminder events
    _connection!.on('ReminderCreated', (arguments) {
      _emitEvent(SignalREventType.reminderCreated, arguments);
    });

    _connection!.on('ReminderUpdated', (arguments) {
      _emitEvent(SignalREventType.reminderUpdated, arguments);
    });

    _connection!.on('ReminderDeleted', (arguments) {
      _emitEvent(SignalREventType.reminderDeleted, arguments);
    });

    // Instance events
    _connection!.on('InstanceCreated', (arguments) {
      _emitEvent(SignalREventType.instanceCreated, arguments);
    });

    _connection!.on('InstanceStatusChanged', (arguments) {
      _emitEvent(SignalREventType.instanceStatusChanged, arguments);
    });

    // Presence
    _connection!.on('UserOnline', (arguments) {
      _emitEvent(SignalREventType.userOnline, arguments);
    });

    // Ping response
    _connection!.on('Pong', (arguments) {
      _emitEvent(SignalREventType.pong, arguments);
    });
  }

  /// Emit event to stream
  void _emitEvent(SignalREventType type, List<Object?>? arguments) {
    debugPrint('SignalR: Received event $type with ${arguments?.length ?? 0} arguments');

    Map<String, dynamic> data = {};

    if (arguments != null && arguments.isNotEmpty) {
      final arg = arguments.first;
      if (arg is Map) {
        data = Map<String, dynamic>.from(arg);
      } else if (arg != null) {
        data = {'value': arg};
      }
    }

    debugPrint('SignalR: Emitting event $type to stream');
    _eventController.add(SignalREvent(type: type, data: data));
  }

  /// Update connection state
  void _updateState(SignalRConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }

  /// Start reconnect timer
  void _startReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('Max reconnect attempts reached');
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () async {
      _reconnectAttempts++;
      debugPrint('Reconnect attempt $_reconnectAttempts');
      await connect();
    });
  }

  /// Stop reconnect timer
  void _stopReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
  }

  /// Start ping timer to keep connection alive
  void _startPing() {
    _stopPing();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (isConnected) {
        try {
          await _connection!.invoke('Ping');
        } catch (e) {
          debugPrint('Ping error: $e');
        }
      }
    });
  }

  /// Stop ping timer
  void _stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _connectionStateController.close();
    _eventController.close();
  }
}
