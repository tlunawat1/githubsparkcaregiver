import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/critical_alert_payload.dart';

typedef CriticalAlertCallback = void Function(CriticalAlertPayload payload);

class CriticalAlertService {
  static final CriticalAlertService _instance = CriticalAlertService._internal();
  factory CriticalAlertService() => _instance;
  CriticalAlertService._internal();

  static const _channel = MethodChannel('critical_alerts');
  static const _storageKey = 'active_critical_alert';

  StreamSubscription? _callkitSubscription;
  CriticalAlertPayload? _activePayload;

  CriticalAlertCallback? onAlertReceived;
  CriticalAlertCallback? onAlertAccepted;
  CriticalAlertCallback? onAlertDismissed;

  Future<void> initialize() async {
    await _restoreActiveAlert();

    _callkitSubscription?.cancel();
    _callkitSubscription = FlutterCallkitIncoming.onEvent.listen((event) {
      if (event == null || event.event == null) {
        return;
      }

      final payload = _payloadFromCallkitEvent(event.body) ?? _activePayload;
      if (payload == null) {
        return;
      }

      switch (event.event) {
        case Event.actionCallAccept:
          onAlertAccepted?.call(payload);
          stopAlert(payload.alertId);
          break;
        case Event.actionCallDecline:
        case Event.actionCallEnded:
          onAlertDismissed?.call(payload);
          stopAlert(payload.alertId);
          break;
        default:
          break;
      }
    });

    if (Platform.isAndroid) {
      final initialRoute = await _channel.invokeMethod<String>('getInitialRoute');
      if (initialRoute != null &&
          initialRoute.isNotEmpty &&
          _activePayload != null &&
          (_activePayload!.route == null || _activePayload!.route!.isEmpty)) {
        _activePayload = _activePayload!.copyWith(route: initialRoute);
        await _persistActiveAlert(_activePayload);
      }
    }
  }

  CriticalAlertPayload? get activePayload => _activePayload;

  Future<void> handleIncomingPayload(CriticalAlertPayload payload,
      {bool fromBackground = false}) async {
    _activePayload = payload;
    await _persistActiveAlert(payload);
    onAlertReceived?.call(payload);

    if (Platform.isIOS) {
      await _showCallkitIncoming(payload);
    } else if (Platform.isAndroid) {
      await _channel.invokeMethod('startRinging', payload.toMap());
    }
  }

  Future<void> stopAlert(String alertId) async {
    if (_activePayload?.alertId == alertId) {
      _activePayload = null;
    }
    await _persistActiveAlert(null);

    if (Platform.isIOS) {
      await FlutterCallkitIncoming.endCall(alertId);
    } else if (Platform.isAndroid) {
      await _channel.invokeMethod('stopRinging', {'alertId': alertId});
    }
  }

  Future<void> _showCallkitIncoming(CriticalAlertPayload payload) async {
    final params = CallKitParams(
      id: payload.alertId,
      nameCaller: payload.title,
      appName: 'Parental Care',
      handle: payload.dependentId ?? payload.sosEventId ?? 'critical',
      type: 0,
      textAccept: 'See Details',
      textDecline: 'Dismiss',
      duration: 0,
      extra: payload.toMap(),
      android: const AndroidParams(
        isCustomNotification: false,
        isShowMissedCallNotification: false,
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

  Future<void> _persistActiveAlert(CriticalAlertPayload? payload) async {
    final prefs = await SharedPreferences.getInstance();
    if (payload == null) {
      await prefs.remove(_storageKey);
    } else {
      await prefs.setString(_storageKey, payload.toJson());
    }
  }

  Future<void> _restoreActiveAlert() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    _activePayload = CriticalAlertPayload.fromJson(stored);
  }

  CriticalAlertPayload? _payloadFromCallkitEvent(Map<String, dynamic>? body) {
    if (body == null || body.isEmpty) return null;
    if (body['extra'] is Map) {
      return CriticalAlertPayload.fromMap(
          Map<String, dynamic>.from(body['extra'] as Map));
    }
    return CriticalAlertPayload.fromMap(body);
  }
}
