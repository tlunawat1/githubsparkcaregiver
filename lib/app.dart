import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/alerts/critical_alert.dart';
import 'core/alerts/critical_alert_call_service.dart';
import 'core/alerts/critical_alert_cubit.dart';
import 'core/di/injection.dart';
import 'core/routing/app_router.dart';
import 'core/services/fcm_service.dart';
import 'core/services/notification_handler.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/remote/remote.dart';
import 'data/repositories/repositories.dart';
import 'features/alerts/presentation/screens/critical_alert_screen.dart';

/// Main application widget 
class ParentalCareApp extends StatefulWidget {
  const ParentalCareApp({super.key});

  @override
  State<ParentalCareApp> createState() => _ParentalCareAppState();
}

class _ParentalCareAppState extends State<ParentalCareApp>
    with WidgetsBindingObserver {
  late AppRouter _appRouter;
  final CriticalAlertCubit _criticalAlertCubit = CriticalAlertCubit();
  final CriticalAlertCallService _criticalAlertCallService =
      CriticalAlertCallService();
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
    _criticalAlertCubit.close();
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
  }

  Future<void> _initializeApp() async {
    final settingsRepository = getIt<SettingsRepository>();
    final apiClient = getIt<ApiClient>();
    final signalRService = getIt<SignalRService>();

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
    _configureCriticalAlertPipeline();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _configureCriticalAlertPipeline() {
    _criticalAlertCallService.initialize();
    _criticalAlertCallService.onCallAccepted = (payload) async {
      await _criticalAlertCubit.stopRinging();
      final route = payload.resolveRoute(userRole: _userRole ?? 'dependent');
      _appRouter.router.go(route);
      await _criticalAlertCallService.endCall(payload.eventId);
      await _criticalAlertCubit.clearActiveAlert();
    };
    _criticalAlertCallService.onCallDeclined = (payload) async {
      await _criticalAlertCubit.stopRinging();
      await _criticalAlertCallService.endCall(payload.eventId);
      await _criticalAlertCubit.clearActiveAlert();
    };

    NotificationHandler().onCriticalAlertReceived = (data) {
      final normalized = _normalizeCriticalData(data);
      final payload = CriticalAlertPayload.fromData(normalized);
      _criticalAlertCallService.showIncoming(payload);
      _criticalAlertCubit.ingest(normalized, suppressLocalRing: true);
    };

    NotificationHandler().onNotificationTapped = (instanceId) {
      if (instanceId == null || instanceId.isEmpty) return;
      _criticalAlertCubit.stopRinging();
      _appRouter.router.go('/dependent/reminder/$instanceId');
    };

    _criticalSignalRSubscription?.cancel();
    final signalRService = getIt<SignalRService>();
    _criticalSignalRSubscription = signalRService.events.listen((event) {
      if (event.type == SignalREventType.sosTriggered) {
        final data = {
          ...event.data,
          'critical': 'true',
          'severity': 'critical',
          'eventType': 'sos_triggered',
          'eventId': event.data['sosEventId'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'title': 'SOS Alert',
          'body': '${event.data['dependentName'] ?? 'A dependent'} needs help now.',
        };
        final payload = CriticalAlertPayload.fromData(data);
        _criticalAlertCallService.showIncoming(payload);
        _criticalAlertCubit.ingest(data, suppressLocalRing: true);
      }

      if (event.type == SignalREventType.instanceStatusChanged) {
        final escalationLevel = (event.data['escalationLevel'] as int?) ?? 0;
        final callStyleEscalationLevel = int.tryParse(
                (event.data['callStyleEscalationLevel'] ?? '1').toString()) ??
            1;
        if (escalationLevel >= callStyleEscalationLevel) {
          final data = {
            ...event.data,
            'critical': 'true',
            'severity': 'critical',
            'eventType': 'urgent_reminder',
            'eventId':
                event.data['eventId'] ?? event.data['instanceId'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
            'title': 'Urgent Reminder',
            'body': 'Immediate attention required.',
          };
          final payload = CriticalAlertPayload.fromData(data);
          _criticalAlertCallService.showIncoming(payload);
          _criticalAlertCubit.ingest(data, suppressLocalRing: true);
        }
      }
    });
  }

  Map<String, dynamic> _normalizeCriticalData(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);
    final escalationLevel = int.tryParse(
            (normalized['escalationLevel'] ?? '0').toString()) ??
        0;
    final callStyleLevel = int.tryParse(
            (normalized['callStyleEscalationLevel'] ??
                    normalized['callStyleThreshold'] ??
                    '2')
                .toString()) ??
        2;
    if (escalationLevel >= callStyleLevel &&
        (normalized['eventType'] == null || normalized['eventType'].toString().isEmpty)) {
      normalized['critical'] = 'true';
      normalized['severity'] = 'critical';
      normalized['eventType'] = 'urgent_reminder';
      normalized['title'] = normalized['title'] ?? 'Urgent Reminder';
      normalized['body'] =
          normalized['body'] ?? 'Immediate attention required.';
      normalized['eventId'] =
          normalized['eventId'] ?? normalized['instanceId'];
    }
    return normalized;
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

    return BlocProvider.value(
      value: _criticalAlertCubit,
      child: MaterialApp.router(
        title: 'Parental Care',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        routerConfig: _appRouter.router,
        builder: (context, child) {
          return Stack(
            children: [
              child ?? const SizedBox.shrink(),
              BlocBuilder<CriticalAlertCubit, CriticalAlertState>(
                builder: (context, state) {
                  if (state.status != CriticalAlertStatus.ringing ||
                      state.activeAlert == null) {
                    return const SizedBox.shrink();
                  }
                  return Positioned.fill(
                    child: CriticalAlertScreen(
                      payload: state.activeAlert!,
                      onSeeDetails: () async {
                        await _criticalAlertCubit.markNavigating();
                        await _criticalAlertCubit.stopRinging();
                        await _criticalAlertCallService.endCall(
                          state.activeAlert!.eventId,
                        );
                        final route = state.activeAlert!.resolveRoute(
                          userRole: _userRole ?? 'dependent',
                        );
                        _appRouter.router.go(route);
                        await _criticalAlertCubit.clearActiveAlert();
                      },
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
