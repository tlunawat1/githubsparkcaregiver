import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Service for managing local notifications for reminders
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const macosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: macosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
    debugPrint('NotificationService initialized');
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Handle notification tap - navigate to reminder alert screen
    // This would be handled by the app's navigation system
  }

  /// Request notification permissions (iOS/macOS)
  Future<bool> requestPermissions() async {
    final iosImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (iosImplementation != null) {
      final granted = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    final macosImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();

    if (macosImplementation != null) {
      final granted = await macosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    // Android permissions are handled differently
    return true;
  }

  /// Schedule a notification for a reminder
  Future<void> scheduleReminderNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    bool isHighPriority = false,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final androidDetails = AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Notifications for scheduled reminders',
      importance: isHighPriority ? Importance.high : Importance.defaultImportance,
      priority: isHighPriority ? Priority.high : Priority.defaultPriority,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: isHighPriority,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );

    debugPrint('Scheduled notification $id for $scheduledTime');
  }

  /// Show an immediate notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool isHighPriority = false,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final androidDetails = AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Notifications for scheduled reminders',
      importance: isHighPriority ? Importance.high : Importance.defaultImportance,
      priority: isHighPriority ? Priority.high : Priority.defaultPriority,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await _notifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Cancel a scheduled notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    debugPrint('Cancelled notification $id');
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    debugPrint('Cancelled all notifications');
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return _notifications.pendingNotificationRequests();
  }
}
