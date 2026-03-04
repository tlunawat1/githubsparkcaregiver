import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import 'core/constants/api_constants.dart';
import 'core/di/injection.dart';
import 'core/routing/app_router.dart';
import 'core/services/fcm_service.dart';
import 'core/services/notification_handler.dart';
import 'core/services/reminder_alarm_service.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/remote/remote.dart';
import 'data/repositories/repositories.dart';
import 'shared/widgets/completion_celebration.dart';
import 'shared/widgets/redesign_ui.dart';
import 'shared/widgets/reminder_button.dart';
import 'shared/widgets/reminder_details_modal.dart';

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

      // If the user was previously authenticated, assume valid until proven
      // otherwise so we can render the home screen immediately.
      if (_isOnboardingComplete && _userRole != null && apiClient.hasSession) {
        _isAuthenticated = true;
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }

    // Create router & wire notification callback IMMEDIATELY so the UI can
    // render and any pending notification tap is processed without waiting
    // for network calls.
    _appRouter = AppRouter(
      isOnboardingComplete: _isOnboardingComplete,
      userRole: _userRole,
      isAuthenticated: _isAuthenticated,
    );

    ReminderAlarmService.instance.navigatorKey = rootNavigatorKey;

    // Wire notification tap handler so ALL reminder notification taps show
    // the bottom sheet overlay with "Yes, Done" / "Not Yet" buttons.
    NotificationHandler().onReminderNotificationTapped = (instanceId, escalationLevel) {
      if (instanceId.isEmpty) return;
      _showReminderOverlay(instanceId, escalationLevel);
    };

    // Show the UI now — don't block on network calls.
    if (mounted) {
      setState(() => _isLoading = false);
    }

    // Run network-dependent initialization in the background.
    // These are non-blocking — the user already sees the home screen.
    if (_isAuthenticated) {
      _initializeServicesInBackground(apiClient, signalRService);
    }

    // Fire-and-forget: ping /health to wake up the backend so it's warm by
    // the time the user reaches login/register (Azure cold-start mitigation).
    _warmUpBackend();
  }

  /// Silent fire-and-forget GET to /health to wake the Azure App Service
  /// worker process. Errors are ignored — it's purely opportunistic.
  void _warmUpBackend() {
    http.get(Uri.parse('${ApiConstants.baseUrl}/health')).then((_) {
      debugPrint('App: Backend warm-up ping succeeded');
    }).catchError((e) {
      debugPrint('App: Backend warm-up ping failed (ignored): $e');
    });
  }

  /// Initialize SignalR, FCM, and token refresh in the background.
  /// If the token turns out to be invalid, redirect to login.
  void _initializeServicesInBackground(
    ApiClient apiClient,
    SignalRService signalRService,
  ) async {
    try {
      // Wire callback: redirect to login when auth is permanently lost.
      apiClient.onAuthenticationRequired = () {
        debugPrint('App: Authentication required, redirecting to login');
        _navigateToLogin();
      };

      // Refresh token in background — if it fails, redirect to login.
      final tokenValid = await apiClient.ensureValidToken();
      if (!tokenValid) {
        debugPrint('App: Token refresh failed on startup, redirecting to login');
        _navigateToLogin();
        return;
      }

      // Wire callback: update SignalR token whenever tokens are refreshed.
      apiClient.onTokensUpdated = (accessToken, refreshToken, expiry) {
        debugPrint('App: Tokens updated, syncing to SignalR');
        signalRService.setAccessToken(accessToken);
      };

      // SignalR & FCM can run in parallel — neither depends on the other.
      signalRService.setAccessToken(apiClient.accessToken);
      final signalRFuture = signalRService.connect().then((_) {
        debugPrint('SignalR connected on app start');
      }).catchError((e) {
        debugPrint('App: SignalR connect failed: $e');
      });

      final fcmFuture = () async {
        final fcmService = getIt<FcmService>();
        await fcmService.initialize();
        await fcmService.registerDeviceToken();
        debugPrint('FCM token registered on app start');
      }().catchError((e) {
        debugPrint('App: FCM registration failed: $e');
      });

      // Wait for both but don't block the UI.
      await Future.wait([signalRFuture, fcmFuture]);
    } catch (e) {
      debugPrint('App: Background services init error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(393, 852),
      minTextAdapt: true,
      splitScreenMode: true,
      // Ensure ScreenUtil re-computes correctly on small / large screens and
      // when the orientation changes.
      ensureScreenSize: true,
      builder: (context, child) {
        final mqData = MediaQuery.of(context);
        final clampedScaler = mqData.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.35,
        );

        if (_isLoading) {
          return MediaQuery(
            data: mqData.copyWith(textScaler: clampedScaler),
            child: MaterialApp(
              title: 'Parental Care',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeMode.system,
              home: const Scaffold(
                body: RedesignBackground(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite,
                          size: 56,
                          color: Color(0xFF13C8EC),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'CareNest',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return MediaQuery(
          data: mqData.copyWith(textScaler: clampedScaler),
          child: MaterialApp.router(
            title: 'Parental Care',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            routerConfig: _appRouter.router,
          ),
        );
      },
    );
  }

  /// Show the reminder overlay bottom sheet with retry logic.
  ///
  /// On cold start the navigator context may not be ready yet, so we retry
  /// after a frame callback and a short delay before giving up.
  void _showReminderOverlay(String instanceId, int escalationLevel, {int attempt = 0}) {
    final context = rootNavigatorKey.currentContext;

    if (context == null) {
      if (attempt >= 3) {
        debugPrint('App: Could not show overlay for $instanceId – no context after $attempt attempts');
        return;
      }

      debugPrint('App: Context not ready (attempt $attempt), scheduling retry for $instanceId');

      if (attempt == 0) {
        // Try again after the current frame finishes.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showReminderOverlay(instanceId, escalationLevel, attempt: attempt + 1);
        });
      } else {
        // Subsequent retries use increasing delays.
        Future<void>.delayed(Duration(milliseconds: 300 * attempt), () {
          _showReminderOverlay(instanceId, escalationLevel, attempt: attempt + 1);
        });
      }
      return;
    }

    // Start fetching data immediately so it loads in parallel with navigation.
    final reminderInstanceApi = getIt<ReminderInstanceApi>();
    final reminderApi = getIt<ReminderApi>();
    final dataFuture = reminderInstanceApi.getInstance(instanceId).then((instance) async {
      ReminderData? reminder;
      if (instance != null) {
        reminder = await reminderApi.getReminder(instance.reminderId);
      }
      return (instance: instance, reminder: reminder);
    }).catchError((e) {
      debugPrint('App: Error pre-fetching reminder data: $e');
      return (instance: null as ReminderInstanceData?, reminder: null as ReminderData?);
    });

    // Navigate to the dependent home screen first, then show the bottom sheet
    // on top of it so the user sees the familiar home screen behind the overlay.
    try {
      GoRouter.of(context).go(AppRoutes.dependentHome);
    } catch (e) {
      debugPrint('App: Could not navigate to dependent home: $e');
    }

    // Wait for BOTH the navigation render AND the data fetch to complete,
    // so the bottom sheet appears instantly with data (no loading spinner).
    // Use 200ms — just enough for the first frame to paint (the GoRouter
    // initial route is already /dependent on cold start, so no real navigation).
    Future.wait([
      dataFuture,
      Future<void>.delayed(const Duration(milliseconds: 200)),
    ]).then((results) {
      final data = results[0] as ({ReminderInstanceData? instance, ReminderData? reminder});
      final instance = data.instance;
      final reminder = data.reminder;

      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null) {
        debugPrint('App: Context lost after navigation for $instanceId');
        return;
      }

      // For urgent (Level >= 2) notifications, start the alarm sound.
      if (escalationLevel >= 2) {
        ReminderAlarmService.instance.startAlarmSound(instanceId);
      }

      // Determine status.
      final status = switch (instance?.status) {
        'completed' => ReminderInstanceStatus.completed,
        'missed' => ReminderInstanceStatus.missed,
        'snoozed' => ReminderInstanceStatus.snoozed,
        _ => ReminderInstanceStatus.pending,
      };
      final isActionable = status == ReminderInstanceStatus.pending ||
          status == ReminderInstanceStatus.snoozed;

      // Show the bottom sheet directly with pre-fetched data (no spinner).
      showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        isDismissible: escalationLevel < 2,
        enableDrag: escalationLevel < 2,
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) {
          return ReminderDetailsModal(
            title: reminder?.title ?? instance?.reminderTitle ?? 'Reminder',
            scheduledTime: instance?.scheduledTime.toLocal() ?? DateTime.now(),
            status: status,
            description: reminder?.description ?? instance?.reminderDescription,
            voiceNoteUrl: reminder?.voiceNoteUrl ?? instance?.voiceNoteUrl,
            onMarkDone: isActionable
                ? () async {
                    try {
                      await reminderInstanceApi.markCompleted(instanceId);
                    } catch (e) {
                      debugPrint('App: Error marking complete: $e');
                    }
                    // Show celebration regardless of API success — the user
                    // already confirmed "Done" and the sheet is dismissed.
                    Future.delayed(const Duration(milliseconds: 400), () {
                      final overlay = rootNavigatorKey.currentState?.overlay;
                      if (overlay != null) {
                        CelebrationOverlay.show(
                          rootNavigatorKey.currentContext!,
                          message: 'Great job!',
                          overlay: overlay,
                        );
                      }
                    });
                  }
                : null,
          );
        },
      ).then((_) {
        // Ensure alarm is stopped if sheet is somehow dismissed.
        if (escalationLevel >= 2 && ReminderAlarmService.instance.isAlarmActive) {
          ReminderAlarmService.instance.stopAlarm();
        }
      });
    });
  }
}
