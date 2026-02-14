import 'dart:async';

import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';

import 'critical_alert.dart';

typedef CriticalCallCallback = void Function(CriticalAlertPayload payload);

class CriticalAlertCallService {
  static final CriticalAlertCallService _instance =
      CriticalAlertCallService._internal();
  factory CriticalAlertCallService() => _instance;
  CriticalAlertCallService._internal();

  StreamSubscription<CallEvent?>? _subscription;
  final Map<String, Timer> _timeoutTimers = {};
  final Set<String> _activeCallIds = <String>{};

  CriticalCallCallback? onCallAccepted;
  CriticalCallCallback? onCallDeclined;

  Future<void> initialize() async {
    await _subscription?.cancel();
    _subscription = FlutterCallkitIncoming.onEvent.listen((event) {
      if (event == null) return;
      final payload = _payloadFromEvent(event.body);
      if (payload == null) return;

      if (event.event == Event.actionCallAccept) {
        onCallAccepted?.call(payload);
        _clearTimeout(payload.eventId);
        _activeCallIds.remove(payload.eventId);
      } else if (event.event == Event.actionCallDecline ||
          event.event == Event.actionCallEnded ||
          event.event == Event.actionCallTimeout) {
        onCallDeclined?.call(payload);
        _clearTimeout(payload.eventId);
        _activeCallIds.remove(payload.eventId);
      }
    });
  }

  Future<void> showIncoming(CriticalAlertPayload payload) async {
    if (_activeCallIds.contains(payload.eventId)) {
      return;
    }
    _activeCallIds.add(payload.eventId);

    _clearTimeout(payload.eventId);
    if ((payload.callTimeoutSeconds ?? 0) > 0) {
      _timeoutTimers[payload.eventId] =
          Timer(Duration(seconds: payload.callTimeoutSeconds!), () async {
        await endCall(payload.eventId);
      });
    }

    final timeoutSeconds = payload.callTimeoutSeconds ?? 0;

    final params = CallKitParams(
      id: payload.eventId,
      nameCaller: payload.title,
      appName: 'Parental Care',
      handle: payload.dependentName ?? payload.dependentId ?? 'critical',
      type: 0,
      // flutter_callkit_incoming expects duration in milliseconds.
      duration: timeoutSeconds > 0 ? timeoutSeconds * 1000 : 0,
      textAccept: 'View Details',
      textDecline: 'Remind Me Later',
      extra: payload.toMap(),
      android: const AndroidParams(
        isCustomNotification: false,
        isShowFullLockedScreen: true,
        isImportant: true,
        ringtonePath: 'system_ringtone_default',
      ),
      ios: const IOSParams(
        handleType: 'generic',
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  Future<void> endCall(String callId) async {
    _clearTimeout(callId);
    _activeCallIds.remove(callId);
    await FlutterCallkitIncoming.endCall(callId);
  }

  CriticalAlertPayload? _payloadFromEvent(dynamic body) {
    if (body is! Map) return null;
    final map = Map<String, dynamic>.from(body as Map);
    if (map['extra'] is Map) {
      return CriticalAlertPayload.fromData(
          Map<String, dynamic>.from(map['extra'] as Map));
    }
    return CriticalAlertPayload.fromData(map);
  }

  void _clearTimeout(String callId) {
    _timeoutTimers.remove(callId)?.cancel();
  }
}
