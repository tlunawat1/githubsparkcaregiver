import 'dart:convert';
import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/feedback_settings.dart';

/// Handles Firebase Cloud Messaging notifications across all app states
class NotificationHandler {
  static final NotificationHandler _instance = NotificationHandler._internal();
  factory NotificationHandler() => _instance;
  NotificationHandler._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Function(String instanceId, int escalationLevel)? _onReminderNotificationTapped;

  /// Pending notification tap that arrived before the callback was wired.
  /// Stored as (instanceId, escalationLevel).
  (String, int)? _pendingReminderTap;

  /// Setter that processes any pending tap as soon as the callback is wired.
  set onReminderNotificationTapped(
      Function(String instanceId, int escalationLevel)? callback) {
    _onReminderNotificationTapped = callback;
    if (callback != null && _pendingReminderTap != null) {
      final (instanceId, level) = _pendingReminderTap!;
      _pendingReminderTap = null;
      debugPrint('NotificationHandler: Processing pending tap for $instanceId (level $level)');
      callback(instanceId, level);
    }
  }

  Function(String instanceId, int escalationLevel)? get onReminderNotificationTapped =>
      _onReminderNotificationTapped;
  static const List<String> _channelIds = [
    'reminders',
    'reminders_high',
    'reminders_urgent',
    'sos_emergency',
  ];

  /// Custom sound for reminder notification channels (Android raw resource name).
  static const _customSound =
      RawResourceAndroidNotificationSound('reminder_alarm');

  static int _parseEscalationLevel(Map<String, dynamic> data) {
    final raw = data['escalationLevel'];
    if (raw == null) return 0;
    if (raw is int) return raw;
    return int.tryParse(raw.toString()) ?? 0;
  }

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
      onDidReceiveNotificationResponse: localNotificationTapHandler,
    );

    // If the app was launched by tapping a local notification (e.g. the urgent/3rd
    // reminder shown from the FCM background handler), the callback above may not
    // fire automatically on cold start. Handle it explicitly here.
    final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
    final launchedFromLocalNotification = launchDetails?.didNotificationLaunchApp ?? false;
    final launchResponse = launchDetails?.notificationResponse;
    if (launchedFromLocalNotification && launchResponse != null) {
      debugPrint('App launched from local notification: ${launchResponse.payload}');
      handleLocalNotificationResponse(launchResponse);
    }

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
        // Default system sound for the first two notifications.
        sound: null,
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
        // Default system sound for the first two notifications.
        sound: null,
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
        sound: playSound ? _customSound : null,
      ),
    );

    // SOS alerts (keep default system sound for SOS)
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

    final type = data['type'] as String?;
    final instanceId = data['instanceId'] as String?;
    final escalationLevel = _parseEscalationLevel(data);

    // ALL reminder notifications with an instanceId: show overlay directly
    // so that foreground behaviour is identical for every escalation level.
    if (type == 'reminder' && instanceId != null) {
      debugPrint('Foreground reminder (level $escalationLevel): showing overlay for instance $instanceId');
      _dispatchOrQueue(instanceId, escalationLevel);
      return;
    }

    // Non-reminder notifications: show in the notification tray.
    if (notification != null) {
      _showLocalNotification(
        title: notification.title ?? 'Notification',
        body: notification.body ?? '',
        payload: json.encode(data),
        channelId: _getChannelId(data),
      );
      return;
    }

    // Data-only non-reminder messages with title/body.
    final title = data['title'] as String?;
    final body = data['body'] as String?;
    if (title != null || body != null) {
      _showLocalNotification(
        title: title ?? 'Notification',
        body: body ?? '',
        payload: json.encode(data),
        channelId: _getChannelId(data),
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.messageId}');

    final instanceId = message.data['instanceId'] as String?;

    // All reminder taps show the overlay bottom sheet.
    if (instanceId != null) {
      final escalationLevel = _parseEscalationLevel(message.data);
      _dispatchOrQueue(instanceId, escalationLevel);
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');
    handleLocalNotificationResponse(response);
  }

  /// Dispatch the notification tap to the callback, or queue it if the
  /// callback hasn't been wired yet (e.g. cold-start race condition).
  void _dispatchOrQueue(String instanceId, int escalationLevel) {
    if (_onReminderNotificationTapped != null) {
      _onReminderNotificationTapped!(instanceId, escalationLevel);
    } else {
      debugPrint(
          'NotificationHandler: Callback not ready, queuing tap for $instanceId (level $escalationLevel)');
      _pendingReminderTap = (instanceId, escalationLevel);
    }
  }

  void handleLocalNotificationResponse(NotificationResponse response) {
    if (response.payload == null) return;

    try {
      final data = json.decode(response.payload!) as Map<String, dynamic>;
      final instanceId = data['instanceId'] as String?;

      // All reminder taps show the overlay bottom sheet.
      if (instanceId != null) {
        final escalationLevel = _parseEscalationLevel(data);
        _dispatchOrQueue(instanceId, escalationLevel);
      }
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
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
      // Default sound for first/second reminders; custom sound only for urgent channel.
      sound: playSound && channelId == 'reminders_urgent' ? _customSound : null,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
      // Default sound for first/second reminders; custom sound only for urgent channel.
      sound: playSound && channelId == 'reminders_urgent' ? 'reminder_alarm.caf' : null,
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

    if (type == 'sos') {
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
}

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message received: ${message.messageId}');

  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // For urgent (3rd) reminder escalations we receive an Android data-only message.
  // Show an *insistent* local notification with the custom sound.
  final data = message.data;
  final type = data['type'] as String?;
  final instanceId = data['instanceId'] as String?;
  final escalationLevel = int.tryParse(data['escalationLevel'] ?? '0') ?? 0;

  if (type != 'reminder' || instanceId == null || escalationLevel < 2) {
    return;
  }

  // If the user is logged out, do NOT play/show the urgent insistent reminder.
  // This avoids continuous ringing when a stale push arrives.
  const secureStorage = FlutterSecureStorage();
  final accessToken = await secureStorage.read(key: 'access_token');
  final expiryRaw = await secureStorage.read(key: 'token_expiry');
  final expiry = expiryRaw != null ? DateTime.tryParse(expiryRaw) : null;
  final hasValidSession = accessToken != null && expiry != null && expiry.isAfter(DateTime.now());
  if (!hasValidSession) {
    debugPrint('Background urgent reminder ignored: user not authenticated');
    return;
  }

  final title = data['title'] ?? 'Reminder';
  final body = data['body'] ?? '';

  final plugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  // IMPORTANT: Provide a tap handler here too. This background isolate init can
  // override the main isolate's callback if omitted, causing taps to only open
  // the app without running our overlay logic.
  await plugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: localNotificationTapHandler,
  );

  // The 'reminders_urgent' channel (with custom sound) is already created by
  // the main isolate in NotificationHandler.initialize(). Do NOT recreate it
  // here — the background isolate cannot resolve raw resources, which causes
  // a PlatformException(invalid_sound) crash.

  final androidDetails = AndroidNotificationDetails(
    'reminders_urgent',
    'Urgent Reminders',
    channelDescription: 'Urgent reminder notifications (escalations)',
    importance: Importance.max,
    priority: Priority.max,
    showWhen: true,
    playSound: true,
    enableVibration: true,
    // Sound is controlled by the channel (created in main isolate).
    // FLAG_INSISTENT (4) - repeat sound until the user interacts.
    additionalFlags: Int32List.fromList(<int>[4]),
  );

  await plugin.show(
    DateTime.now().millisecondsSinceEpoch.remainder(100000),
    title,
    body,
    NotificationDetails(android: androidDetails),
    payload: json.encode(data),
  );
}

/// Local notification response handler - must be top-level.
///
/// This is used both by the main app and by the FCM background handler's
/// local-notification initialization, so taps reliably route to our logic.
@pragma('vm:entry-point')
void localNotificationTapHandler(NotificationResponse response) {
  NotificationHandler().handleLocalNotificationResponse(response);
}
