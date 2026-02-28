import 'package:flutter/material.dart';

import 'core/di/injection.dart';
import 'core/routing/app_router.dart';
import 'core/services/fcm_service.dart';
import 'core/services/reminder_alarm_service.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/remote/remote.dart';
import 'data/repositories/repositories.dart';
import 'shared/widgets/redesign_ui.dart';

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
  bool _isAuthenticated = false;

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

    // Proactively refresh token if expired (before any API calls)
    if (apiClient.hasSession) {
      final tokenValid = await apiClient.ensureValidToken();

      if (tokenValid) {
        // Update SignalR with the (possibly refreshed) token
        signalRService.setAccessToken(apiClient.accessToken);

        final wasConnected = signalRService.isConnected;
        debugPrint('App: SignalR was connected: $wasConnected');

        if (!wasConnected) {
          debugPrint('App: Reconnecting SignalR after resume...');
          await signalRService.ensureConnected();
        } else {
          debugPrint('App: Verifying SignalR connection...');
          try {
            await signalRService.ensureConnected();
          } catch (e) {
            debugPrint('App: SignalR verification failed, reconnecting: $e');
            await signalRService.connect();
          }
        }
      } else if (!apiClient.hasSession) {
        // Refresh token was explicitly rejected by server -- force re-login
        debugPrint('App: Session expired during resume, redirecting to login');
        _navigateToLogin();
      }
    }
  }

  /// Navigate user to the welcome/login screen
  void _navigateToLogin() {
    final context = rootNavigatorKey.currentContext;
    if (context != null && mounted) {
      AppRouter.goToWelcome(context);
    }
  }

  Future<void> _initializeApp() async {
    final settingsRepository = getIt<SettingsRepository>();
    final apiClient = getIt<ApiClient>();
    final signalRService = getIt<SignalRService>();

    try {
      _isOnboardingComplete = await settingsRepository.isOnboardingComplete();
      _userRole = await settingsRepository.getUserRole();

      if (_isOnboardingComplete && _userRole != null && apiClient.hasSession) {
        // Proactively refresh token if expired before initializing services
        _isAuthenticated = await apiClient.ensureValidToken();

        if (_isAuthenticated) {
          // Wire callback: update SignalR token whenever tokens are refreshed
          apiClient.onTokensUpdated = (accessToken, refreshToken, expiry) {
            debugPrint('App: Tokens updated, syncing to SignalR');
            signalRService.setAccessToken(accessToken);
          };

          // Wire callback: redirect to login when auth is permanently lost
          apiClient.onAuthenticationRequired = () {
            debugPrint('App: Authentication required, redirecting to login');
            _navigateToLogin();
          };

          signalRService.setAccessToken(apiClient.accessToken);
          signalRService.connect();
          debugPrint('SignalR connecting on app start');

          final fcmService = FcmService(getIt<UserApi>());
          await fcmService.initialize();
          await fcmService.registerDeviceToken();
          debugPrint('FCM token registered on app start');
        } else {
          debugPrint(
            'App: Token refresh failed on startup, user needs to re-login',
          );
          // Still wire the callback for future use
          apiClient.onAuthenticationRequired = () {
            debugPrint('App: Authentication required, redirecting to login');
            _navigateToLogin();
          };
        }
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }

    _appRouter = AppRouter(
      isOnboardingComplete: _isOnboardingComplete,
      userRole: _userRole,
      isAuthenticated: _isAuthenticated,
    );

    ReminderAlarmService.instance.navigatorKey = rootNavigatorKey;

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
          body: RedesignBackground(
            child: Center(child: CircularProgressIndicator()),
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
