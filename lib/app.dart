import 'package:flutter/material.dart';

import 'core/di/injection.dart';
import 'core/routing/app_router.dart';
import 'core/services/fcm_service.dart';
import 'core/models/critical_alert_payload.dart';
import 'core/services/critical_alert_service.dart';
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
  StreamSubscription? _signalRSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _signalRSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    } else if (state == AppLifecycleState.paused) {
      debugPrint('App: Paused (going to background)');
    }
  }

  /// Handle app resume from background
  Future<void> _onAppResumed() async {
    debugPrint('App: Resumed from background');
    
    final apiClient = getIt<ApiClient>();
    final signalRService = getIt<SignalRService>();
    
    // Only manage SignalR if user is authenticated
    if (apiClient.isAuthenticated) {
      // Ensure SignalR is connected
      final wasConnected = signalRService.isConnected;
      debugPrint('App: SignalR was connected: $wasConnected');
      
      if (!wasConnected) {
        debugPrint('App: Reconnecting SignalR after resume...');
        signalRService.setAccessToken(apiClient.accessToken);
        await signalRService.ensureConnected();
      } else {
        // Even if appears connected, verify by attempting a ping
        // The connection might be stale
        debugPrint('App: Verifying SignalR connection...');
        try {
          // Force a connection check by ensuring we're connected
          await signalRService.ensureConnected();
        } catch (e) {
          debugPrint('App: SignalR verification failed, reconnecting: $e');
          await signalRService.connect();
        }
      }
    }

    final activeAlert = CriticalAlertService().activePayload;
    if (activeAlert != null) {
      _appRouter.router.go(AppRoutes.criticalAlert, extra: activeAlert);
    }
  }

  Future<void> _initializeApp() async {
    final settingsRepository = getIt<SettingsRepository>();
    final apiClient = getIt<ApiClient>();
    final signalRService = getIt<SignalRService>();
    final criticalAlertService = CriticalAlertService();

    try {
      _isOnboardingComplete = await settingsRepository.isOnboardingComplete();
      _userRole = await settingsRepository.getUserRole();

      // Connect SignalR and register FCM token if user is already authenticated
      if (_isOnboardingComplete && _userRole != null && apiClient.isAuthenticated) {
        signalRService.setAccessToken(apiClient.accessToken);
        signalRService.connect();
        debugPrint('SignalR connecting on app start');

        // Initialize FCM and register device token
        final fcmService = FcmService(getIt<UserApi>());
        await fcmService.initialize();
        await fcmService.registerDeviceToken();
        debugPrint('FCM token registered on app start');
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }

    _appRouter = AppRouter(
      isOnboardingComplete: _isOnboardingComplete,
      userRole: _userRole,
    );

    await criticalAlertService.initialize();

    NotificationHandler().onNotificationTapped = (instanceId) {
      if (instanceId == null || instanceId.isEmpty) return;
      _appRouter.router.go('/dependent/reminder/$instanceId');
    };

    NotificationHandler().onCriticalAlertReceived = (payload) {
      _appRouter.router.go(AppRoutes.criticalAlert, extra: payload);
    };

    criticalAlertService.onAlertReceived = (payload) {
      _appRouter.router.go(AppRoutes.criticalAlert, extra: payload);
    };

    criticalAlertService.onAlertAccepted = (payload) {
      _appRouter.router.go(payload.resolvedRoute);
    };

    criticalAlertService.onAlertDismissed = (payload) {
      if (_appRouter.router.location == AppRoutes.criticalAlert) {
        _appRouter.router.go(payload.resolvedRoute);
      }
    };

    _signalRSubscription = signalRService.events.listen((event) {
      if (event.type == SignalREventType.sosTriggered) {
        final payload = CriticalAlertPayload.fromMap({
          ...event.data,
          'type': 'critical_alert',
          'alertType': 'sos',
          'title': 'SOS Alert!',
          'body': '${event.data['dependentName'] ?? 'A dependent'} needs help!',
          'alertId': event.data['sosEventId'] ?? event.data['dependentId'] ?? '',
        });
        NotificationHandler().onCriticalAlertReceived?.call(payload);
      }
    });

    if (mounted) {
      setState(() => _isLoading = false);
    }
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
