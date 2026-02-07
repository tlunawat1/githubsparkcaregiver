import 'package:flutter/material.dart';

import 'core/di/injection.dart';
import 'core/routing/app_router.dart';
import 'core/services/fcm_service.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
