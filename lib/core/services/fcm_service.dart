import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:parental_care_app/data/datasources/remote/user_api.dart';

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final UserApi _userApi;

  String? _currentToken;

  /// When true, token refresh events are ignored (prevents re-registration
  /// after logout calls deleteToken, which can trigger onTokenRefresh).
  bool _suppressRegistration = false;

  FcmService(this._userApi);

  String? get currentToken => _currentToken;

  Future<void> initialize() async {
    // Request notification permissions
    await requestPermissions();

    // Get the FCM token
    _currentToken = await _messaging.getToken();
    debugPrint('FCM Token: $_currentToken');

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_handleTokenRefresh);
  }

  Future<NotificationSettings> requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');
    return settings;
  }

  Future<void> registerDeviceToken() async {
    if (_suppressRegistration) {
      debugPrint('FCM: registration suppressed (logout in progress)');
      return;
    }

    if (_currentToken == null) {
      _currentToken = await _messaging.getToken();
    }

    if (_currentToken != null) {
      try {
        final platform = Platform.isIOS ? 'iOS' : 'Android';
        await _userApi.registerDeviceToken(
          token: _currentToken!,
          platform: platform,
        );

        // Backward-compat: some backend paths still read Users.DeviceToken.
        // Keep it in sync until everything is migrated to UserDeviceTokens.
        await _userApi.updateDeviceToken(_currentToken!);
        debugPrint('Device token registered successfully');
      } catch (e) {
        debugPrint('Failed to register device token: $e');
      }
    }
  }

  void _handleTokenRefresh(String newToken) async {
    debugPrint('FCM Token refreshed: $newToken');
    if (_suppressRegistration) {
      debugPrint('FCM: ignoring token refresh (logout in progress)');
      return;
    }
    _currentToken = newToken;

    // Re-register the new token with the backend
    await registerDeviceToken();
  }

  Future<void> invalidateToken() async {
    if (_currentToken != null) {
      try {
        await _userApi.invalidateDeviceToken(_currentToken!);
        debugPrint('Device token invalidated');
      } catch (e) {
        debugPrint('Failed to invalidate device token: $e');
      }
    }
  }

  Future<void> deleteToken() async {
    await _messaging.deleteToken();
    _currentToken = null;
    debugPrint('FCM token deleted');
  }

  /// Full cleanup for logout: invalidates the server-side token, suppresses
  /// any re-registration from onTokenRefresh, then deletes the local FCM token.
  Future<void> cleanupForLogout() async {
    _suppressRegistration = true;
    await invalidateToken();
    try {
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('FCM: error deleting token during logout: $e');
    }
    _currentToken = null;
    debugPrint('FCM: full logout cleanup done');
  }

  /// Re-enable token registration (called after a fresh login).
  void enableRegistration() {
    _suppressRegistration = false;
  }

  Future<String?> getApnsToken() async {
    if (Platform.isIOS) {
      return await _messaging.getAPNSToken();
    }
    return null;
  }

  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('Subscribed to topic: $topic');
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from topic: $topic');
  }
}
