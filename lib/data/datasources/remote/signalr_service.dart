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

  final String hubUrl;
  HubConnection? _connection;
  String? _accessToken;

  SignalRConnectionState _connectionState = SignalRConnectionState.disconnected;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

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

  SignalRService({String? hubUrl}) : hubUrl = hubUrl ?? _defaultHubUrl;

  /// Set access token for authentication
  void setAccessToken(String? token) {
    _accessToken = token;
  }

  /// Connect to SignalR hub
  Future<void> connect() async {
    if (_connection != null &&
        _connectionState == SignalRConnectionState.connected) {
      return;
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
        _updateState(SignalRConnectionState.connected);
        _reconnectAttempts = 0;
        _startPing();
      });

      await _connection!.start();
      _updateState(SignalRConnectionState.connected);
      _reconnectAttempts = 0;
      _startPing();

      debugPrint('SignalR connected');
    } catch (e) {
      debugPrint('SignalR connection error: $e');
      _updateState(SignalRConnectionState.disconnected);
      _startReconnect();
    }
  }

  /// Disconnect from SignalR hub
  Future<void> disconnect() async {
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

    _updateState(SignalRConnectionState.disconnected);
  }

  /// Subscribe to updates for a specific dependent (for caregivers)
  Future<void> subscribeToDependent(String dependentId) async {
    if (!isConnected) return;

    try {
      await _connection!.invoke('SubscribeToDependent', args: [dependentId]);
      debugPrint('Subscribed to dependent: $dependentId');
    } catch (e) {
      debugPrint('Error subscribing to dependent: $e');
    }
  }

  /// Unsubscribe from dependent updates
  Future<void> unsubscribeFromDependent(String dependentId) async {
    if (!isConnected) return;

    try {
      await _connection!.invoke('UnsubscribeFromDependent', args: [dependentId]);
      debugPrint('Unsubscribed from dependent: $dependentId');
    } catch (e) {
      debugPrint('Error unsubscribing from dependent: $e');
    }
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
    Map<String, dynamic> data = {};

    if (arguments != null && arguments.isNotEmpty) {
      final arg = arguments.first;
      if (arg is Map) {
        data = Map<String, dynamic>.from(arg);
      } else if (arg != null) {
        data = {'value': arg};
      }
    }

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
