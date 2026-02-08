import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/critical_alert_payload.dart';
import '../../data/datasources/remote/critical_alert_api.dart';
import '../bloc/critical_alert/critical_alert_cubit.dart';

class CriticalAlertCoordinator {
  static final CriticalAlertCoordinator instance =
      CriticalAlertCoordinator._internal();

  static const _pendingAlertKey = 'critical_alert.pending';

  CriticalAlertCoordinator._internal();

  Stream<CallEvent?> get callkitEvents => FlutterCallkitIncoming.onEvent;

  Future<void> initialize({
    required CriticalAlertApi criticalAlertApi,
    required CriticalAlertCubit criticalAlertCubit,
    required void Function(String route) onRouteRequested,
  }) async {
    if (Platform.isAndroid) {
      final canUse = await FlutterCallkitIncoming.canUseFullScreenIntent();
      if (!canUse) {
        await FlutterCallkitIncoming.requestFullIntentPermission();
      }
      await FlutterCallkitIncoming.requestNotificationPermission({});
    }

    callkitEvents.listen((event) async {
      if (event == null) return;

      final eventType = event.event;
      final body = event.body;
      if (body is! Map) return;

      final payload = CriticalAlertPayload.fromMap(
        Map<String, dynamic>.from(body),
      );

      if (eventType == Event.actionCallAccept) {
        await _acknowledgeAlert(
          criticalAlertApi: criticalAlertApi,
          alertId: payload.alertId,
          status: 'accepted',
        );
        criticalAlertCubit.stopRinging();
        await FlutterCallkitIncoming.endCall(payload.alertId);
        final route = payload.route ?? _buildRoute(payload);
        await _persistPendingRoute(route);
        onRouteRequested(route);
      }

      if (eventType == Event.actionCallDecline ||
          eventType == Event.actionCallEnded) {
        await _acknowledgeAlert(
          criticalAlertApi: criticalAlertApi,
          alertId: payload.alertId,
          status: 'declined',
        );
        criticalAlertCubit.stopRinging();
        await FlutterCallkitIncoming.endCall(payload.alertId);
        await clearPendingRoute();
      }
    });
  }

  Future<void> handleIncomingAlert(
    CriticalAlertPayload payload,
    CriticalAlertCubit criticalAlertCubit,
  ) async {
    if (payload.alertId.isEmpty) return;
    if (await _hasPendingAlert(payload.alertId)) {
      return;
    }

    criticalAlertCubit.startRinging(payload);
    await _persistPendingRoute(payload.route ?? _buildRoute(payload));

    final params = CallKitParams(
      id: payload.alertId,
      nameCaller: _callerName(payload),
      appName: 'Parental Care',
      handle: payload.dependentName ?? 'Emergency',
      type: 0,
      textAccept: 'View',
      textDecline: 'Stop',
      duration: 0,
      extra: payload.toMap(),
      android: AndroidParams(
        isShowFullLockedScreen: true,
        isImportant: true,
        incomingCallNotificationChannelName: 'Critical Alerts',
        missedCallNotificationChannelName: 'Missed Critical Alerts',
      ),
      ios: IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: false,
        supportsHolding: false,
        supportsDTMF: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        configureAudioSession: true,
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  bool isCriticalAlert(Map<String, dynamic> data) {
    final priority = data['priority']?.toString();
    final type = data['type']?.toString();
    return priority == 'critical' ||
        type == 'sos_triggered' ||
        type == 'reminder_urgent';
  }

  CriticalAlertPayload fromData(Map<String, dynamic> data) {
    return CriticalAlertPayload.fromMap(data);
  }

  Future<String?> getVoipToken() async {
    if (!Platform.isIOS) return null;
    final token = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
    return token?.toString();
  }

  Future<void> _acknowledgeAlert({
    required CriticalAlertApi criticalAlertApi,
    required String alertId,
    required String status,
  }) async {
    if (alertId.isEmpty) return;
    try {
      await criticalAlertApi.acknowledgeAlert(alertId: alertId, status: status);
    } catch (e) {
      debugPrint('Failed to acknowledge alert: $e');
    }
  }

  String _buildRoute(CriticalAlertPayload payload) {
    if (payload.type == 'sos_triggered' && payload.sosEventId != null) {
      return '/dependent/sos';
    }
    if (payload.instanceId != null) {
      return '/dependent/reminder/${payload.instanceId}';
    }
    return '/';
  }

  String _callerName(CriticalAlertPayload payload) {
    if (payload.type == 'sos_triggered') {
      return 'Emergency SOS';
    }
    if (payload.type == 'reminder_urgent') {
      return 'Urgent Reminder';
    }
    return 'Critical Alert';
  }

  Future<void> _persistPendingRoute(String route) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingAlertKey, route);
  }

  Future<bool> _hasPendingAlert(String alertId) async {
    final prefs = await SharedPreferences.getInstance();
    final route = prefs.getString(_pendingAlertKey);
    return route != null && route.isNotEmpty;
  }

  Future<String?> consumePendingRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final route = prefs.getString(_pendingAlertKey);
    if (route != null) {
      await prefs.remove(_pendingAlertKey);
    }
    return route;
  }

  Future<void> clearPendingRoute() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingAlertKey);
  }
}
