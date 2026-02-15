import 'dart:async';

import 'package:flutter/material.dart';

import 'core/di/injection.dart';
import 'core/routing/app_router.dart';
import 'core/services/fcm_service.dart';
import 'core/services/notification_handler.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/remote/remote.dart';
import 'data/repositories/repositories.dart';

/// Main application widget
class ParentalCareApp extends StatefulWidget {
  const ParentalCareApp({super.key});

  @override
  State<ParentalCareApp> createState() => _ParentalCareAppState();
}

class _ParentalCareAppState extends State<ParentalCareApp>
    with WidgetsBindingObserver {
  late AppRouter _appRouter;
  bool _isLoading = true;
  bool _isOnboardingComplete = false;
  String? _userRole;
  StreamSubscription<SignalREvent>? _criticalSignalRSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _criticalSignalRSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  Future<void> _onAppResumed() async {
    final apiClient = getIt<ApiClient>();
    final signalRService = getIt<SignalRService>();

    if (apiClient.isAuthenticated) {
      signalRService.setAccessToken(apiClient.accessToken);
      await signalRService.ensureConnected();
    }
  }

  Future<void> _initializeApp() async {
    final settingsRepository = getIt<SettingsRepository>();
    final apiClient = getIt<ApiClient>();
    final signalRService = getIt<SignalRService>();

    try {
      _isOnboardingComplete = await settingsRepository.isOnboardingComplete();
      _userRole = await settingsRepository.getUserRole();

      if (_isOnboardingComplete && _userRole != null && apiClient.isAuthenticated) {
        signalRService.setAccessToken(apiClient.accessToken);
        signalRService.connect();

        final fcmService = FcmService(getIt<UserApi>());
        await fcmService.initialize();
        await fcmService.registerDeviceToken();
      }
    } catch (e) {
      debugPrint('Error during app initialization: $e');
    }

    _appRouter = AppRouter(
      isOnboardingComplete: _isOnboardingComplete,
      userRole: _userRole,
    );

    _configureCriticalAlertPipeline();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _configureCriticalAlertPipeline() {
    NotificationHandler().onCriticalAlertReceived = (data) {
      debugPrint('Critical reminder payload received: ${data['instanceId'] ?? data['id']}');
    };

    NotificationHandler().onNotificationTapped = (instanceId) {
      if (instanceId == null || instanceId.isEmpty) return;
      _appRouter.router.go('/dependent/reminder/$instanceId');
    };

    NotificationHandler().onDoneActionRequested = (instanceId) async {
      try {
        await getIt<ReminderInstanceApi>().markCompleted(instanceId);
        debugPrint('Marked reminder instance as completed: $instanceId');
      } catch (e) {
        debugPrint('Failed to mark reminder done ($instanceId): $e');
      }
    };

    NotificationHandler().onDeclineActionRequested = (instanceId) async {
      try {
        await getIt<ReminderInstanceApi>().markMissed(instanceId);
        debugPrint('Marked reminder instance as declined/missed: $instanceId');
      } catch (e) {
        debugPrint('Failed to mark reminder declined ($instanceId): $e');
      }
    };

    _criticalSignalRSubscription?.cancel();
    _criticalSignalRSubscription = getIt<SignalRService>().events.listen((event) async {
      if (event.type == SignalREventType.sosTriggered) {
        final data = _normalizeCriticalData({
          ...event.data,
          'type': event.data['type'] ?? 'sos',
          'title': event.data['title'] ?? 'SOS Emergency Alert',
          'body': event.data['body'] ?? 'Immediate assistance is required.',
        });

        await NotificationHandler().showExternalNotification(
          title: data['title']?.toString() ?? 'SOS Emergency Alert',
          body: data['body']?.toString() ?? 'Immediate assistance is required.',
          data: data,
        );
        return;
      }

      if (event.type == SignalREventType.instanceStatusChanged) {
        final status = event.data['status']?.toString().toLowerCase();
        if (status == 'escalated') {
          final reminderTitle =
              event.data['title']?.toString() ?? event.data['reminderTitle']?.toString();
          final senderName =
              event.data['senderName']?.toString() ?? event.data['caregiverName']?.toString();
          final body = _buildCriticalBody(
            reminderTitle: reminderTitle,
            senderName: senderName,
          );

          final data = _normalizeCriticalData({
            ...event.data,
            'title': event.data['title'] ?? 'Critical Reminder Alert',
            'body': body,
          });

          await NotificationHandler().showExternalNotification(
            title: data['title']?.toString() ?? 'Critical Reminder Alert',
            body: data['body']?.toString() ?? body,
            data: data,
          );
        }
      }
    });
  }

  Map<String, dynamic> _normalizeCriticalData(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);
    normalized['critical'] = 'true';
    normalized['severity'] = 'critical';
    normalized['instanceId'] =
        normalized['instanceId'] ?? normalized['reminderInstanceId'] ?? normalized['id'];
    normalized['eventType'] =
        normalized['eventType'] ?? normalized['type'] ?? 'urgent_reminder';
    return normalized;
  }

  String _buildCriticalBody({String? reminderTitle, String? senderName}) {
    if (senderName != null && senderName.trim().isNotEmpty) {
      if (reminderTitle != null && reminderTitle.trim().isNotEmpty) {
        return '$senderName marked "$reminderTitle" as critical.';
      }
      return '$senderName marked a reminder as critical.';
    }

    if (reminderTitle != null && reminderTitle.trim().isNotEmpty) {
      return 'Critical attention needed for "$reminderTitle".';
    }

    return 'Immediate attention is required for this reminder.';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        title: 'Parental Care',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp.router(
      title: 'Parental Care',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: _appRouter.router,
    );
  }
}
