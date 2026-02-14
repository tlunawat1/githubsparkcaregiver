import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../bloc/critical_alert/critical_alert_cubit.dart';
import '../di/injection.dart';
import '../models/critical_alert_payload.dart';
import '../services/critical_alert_coordinator.dart';
import '../../data/datasources/remote/critical_alert_api.dart';
import '../utils/feedback_settings.dart';

/// Handles Firebase Cloud Messaging notifications across all app states
class NotificationHandler {
  static final NotificationHandler _instance = NotificationHandler._internal();
  factory NotificationHandler() => _instance;
  NotificationHandler._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Function(String? instanceId)? onNotificationTapped;
  static const List<String> _channelIds = [
    'reminders',
    'reminders_high',
    'reminders_urgent',
    'sos_emergency',
  ];

  Future<void> initialize() async {
    // Initialize local notifications for foreground display
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    await _createNotificationChannels(forceRecreate: true);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle notification tap when app was terminated
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  Future<void> refreshNotificationChannels() async {
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    for (final channelId in _channelIds) {
      await androidPlugin.deleteNotificationChannel(channelId);
    }

    await _createNotificationChannels(forceRecreate: false);
  }

  Future<void> _createNotificationChannels({required bool forceRecreate}) async {
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    if (forceRecreate) {
      for (final channelId in _channelIds) {
        await androidPlugin.deleteNotificationChannel(channelId);
      }
    }

    await FeedbackSettings.refresh();
    final playSound = FeedbackSettings.notificationSoundEnabled;
    final enableVibration = FeedbackSettings.hapticFeedbackEnabled;

    // Reminders channel
    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        'reminders',
        'Reminders',
        description: 'Reminder notifications',
        importance: Importance.high,
        playSound: playSound,
        enableVibration: enableVibration,
      ),
    );

    // High priority reminders
    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        'reminders_high',
        'Important Reminders',
        description: 'High priority reminder notifications',
        importance: Importance.max,
        playSound: playSound,
        enableVibration: enableVibration,
      ),
    );

    // Urgent reminders (escalations)
    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        'reminders_urgent',
        'Urgent Reminders',
        description: 'Urgent reminder notifications (escalations)',
        importance: Importance.max,
        playSound: playSound,
        enableVibration: enableVibration,
      ),
    );

    // SOS alerts
    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        'sos_emergency',
        'SOS Alerts',
        description: 'Emergency SOS alerts',
        importance: Importance.max,
        playSound: playSound,
        enableVibration: enableVibration,
      ),
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message received: ${message.messageId}');

    final notification = message.notification;
    final data = message.data;

    if (_isCriticalAlert(data)) {
      final payload = _criticalAlertPayload(data);
      _handleCriticalAlert(payload);
      return;
    }

    if (notification != null) {
      // Show local notification since FCM doesn't auto-show in foreground
      _showLocalNotification(
        title: notification.title ?? 'Reminder',
        body: notification.body ?? '',
        payload: json.encode(data),
        channelId: _getChannelId(data),
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.messageId}');

    final instanceId = message.data['instanceId'] as String?;
    if (instanceId != null && onNotificationTapped != null) {
      onNotificationTapped!(instanceId);
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');

    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!) as Map<String, dynamic>;
        if (_isCriticalAlert(data)) {
          final payload = _criticalAlertPayload(data);
          _handleCriticalAlert(payload);
          return;
        }
        final instanceId = data['instanceId'] as String?;
        if (instanceId != null && onNotificationTapped != null) {
          onNotificationTapped!(instanceId);
        }
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = 'reminders',
  }) async {
    await FeedbackSettings.refresh();
    final playSound = FeedbackSettings.notificationSoundEnabled;
    final enableVibration = FeedbackSettings.hapticFeedbackEnabled;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: 'Reminder notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: enableVibration,
      playSound: playSound,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  String _getChannelId(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final escalationLevel = int.tryParse(data['escalationLevel'] ?? '0') ?? 0;

    if (type == 'sos' || type == 'sos_triggered') {
      return 'sos_emergency';
    }

    if (escalationLevel >= 2) {
      return 'reminders_urgent';
    }

    if (escalationLevel >= 1) {
      return 'reminders_high';
    }

    return 'reminders';
  }

  String _getChannelName(String channelId) {
    switch (channelId) {
      case 'reminders_urgent':
        return 'Urgent Reminders';
      case 'reminders_high':
        return 'Important Reminders';
      case 'sos_emergency':
        return 'SOS Alerts';
      default:
        return 'Reminders';
    }
  }

  bool _isCriticalAlert(Map<String, dynamic> data) {
    return CriticalAlertCoordinator.instance.isCriticalAlert(data);
  }

  CriticalAlertPayload _criticalAlertPayload(Map<String, dynamic> data) {
    return CriticalAlertCoordinator.instance.fromData(data);
  }

  void _handleCriticalAlert(CriticalAlertPayload payload) {
    final criticalAlertApi = getIt<CriticalAlertApi>();
    final criticalAlertCubit = getIt<CriticalAlertCubit>();

    CriticalAlertCoordinator.instance.handleIncomingAlert(
      payload,
      criticalAlertCubit,
    );
  }
}

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message received: ${message.messageId}');
  final data = message.data;
  if (CriticalAlertCoordinator.instance.isCriticalAlert(data)) {
    await configureDependencies();
    final payload = CriticalAlertCoordinator.instance.fromData(data);
    final criticalAlertCubit = getIt<CriticalAlertCubit>();
    await CriticalAlertCoordinator.instance.handleIncomingAlert(
      payload,
      criticalAlertCubit,
    );
  }
}
