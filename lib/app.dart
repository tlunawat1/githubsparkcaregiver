import 'package:flutter/material.dart';

import 'core/di/injection.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/repositories.dart';

/// Main application widget
class ParentalCareApp extends StatefulWidget {
  const ParentalCareApp({super.key});

  @override
  State<ParentalCareApp> createState() => _ParentalCareAppState();
}

class _ParentalCareAppState extends State<ParentalCareApp> {
  late AppRouter _appRouter;
  bool _isLoading = true;
  bool _isOnboardingComplete = false;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final settingsRepository = getIt<SettingsRepository>();

    try {
      _isOnboardingComplete = await settingsRepository.isOnboardingComplete();
      _userRole = await settingsRepository.getUserRole();
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
