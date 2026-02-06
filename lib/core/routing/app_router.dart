import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/role_selection_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/auth/presentation/screens/profile_setup_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/registration_screen.dart';
import '../../features/auth/presentation/screens/email_verification_screen.dart';
import '../../features/caregiver/presentation/screens/caregiver_home_screen.dart';
import '../../features/caregiver/presentation/screens/dependent_selector_screen.dart';
import '../../features/caregiver/presentation/screens/dependent_dashboard_screen.dart';
import '../../features/caregiver/presentation/screens/emergency_contacts_screen.dart';
import '../../features/dependent/presentation/screens/dependent_home_screen.dart';
import '../../features/dependent/presentation/screens/reminder_alert_screen.dart';
import '../../features/dependent/presentation/screens/sos_screen.dart';
import '../../features/reminders/presentation/screens/add_reminder_screen.dart';
import '../../features/reminders/presentation/screens/edit_reminder_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/timezone_settings_screen.dart';
import '../../features/settings/presentation/screens/edit_profile_screen.dart';
import '../../features/settings/presentation/screens/linked_user_detail_screen.dart';

/// Route names for type-safe navigation
class AppRoutes {
  static const String welcome = '/';
  static const String roleSelection = '/role-selection';
  static const String profileSetup = '/profile-setup';

  // Authentication routes
  static const String login = '/login';
  static const String register = '/register';
  static const String emailVerification = '/email-verification';

  // Caregiver routes
  static const String caregiverHome = '/caregiver';
  static const String dependentSelector = '/caregiver/dependents';
  static const String dependentDashboard = '/caregiver/dependent/:dependentId';
  static const String addReminder = '/caregiver/dependent/:dependentId/add-reminder';
  static const String editReminder = '/caregiver/reminder/:reminderId/edit';
  static const String emergencyContacts = '/caregiver/dependent/:dependentId/emergency-contacts';

  // Dependent routes
  static const String dependentHome = '/dependent';
  static const String reminderAlert = '/dependent/reminder/:instanceId';
  static const String sos = '/dependent/sos';

  // Shared routes
  static const String settings = '/settings';
  static const String timezoneSettings = '/settings/timezone';
  static const String editProfile = '/settings/edit-profile';
  static const String linkedUserDetail = '/settings/linked-user';
}

/// App router configuration
class AppRouter {
  final bool isOnboardingComplete;
  final String? userRole;

  AppRouter({
    required this.isOnboardingComplete,
    this.userRole,
  });

  late final GoRouter router = GoRouter(
    initialLocation: _getInitialLocation(),
    debugLogDiagnostics: true,
    routes: [
      // Onboarding routes
      GoRoute(
        path: AppRoutes.welcome,
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.roleSelection,
        name: 'roleSelection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        name: 'profileSetup',
        builder: (context, state) {
          final role = state.uri.queryParameters['role'] ?? 'caregiver';
          return ProfileSetupScreen(role: role);
        },
      ),

      // Authentication routes
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) {
          final role = state.uri.queryParameters['role'] ?? 'caregiver';
          return LoginScreen(role: role);
        },
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) {
          final role = state.uri.queryParameters['role'] ?? 'caregiver';
          return RegistrationScreen(role: role);
        },
      ),
      GoRoute(
        path: AppRoutes.emailVerification,
        name: 'emailVerification',
        builder: (context, state) {
          final userId = state.uri.queryParameters['userId'] ?? '';
          final role = state.uri.queryParameters['role'] ?? 'caregiver';
          final email = state.uri.queryParameters['email'] ?? '';
          return EmailVerificationScreen(userId: userId, role: role, email: email);
        },
      ),

      // Caregiver routes
      GoRoute(
        path: AppRoutes.caregiverHome,
        name: 'caregiverHome',
        builder: (context, state) => const CaregiverHomeScreen(),
        routes: [
          GoRoute(
            path: 'dependents',
            name: 'dependentSelector',
            builder: (context, state) => const DependentSelectorScreen(),
          ),
          GoRoute(
            path: 'dependent/:dependentId',
            name: 'dependentDashboard',
            builder: (context, state) {
              final dependentId = state.pathParameters['dependentId']!;
              return DependentDashboardScreen(dependentId: dependentId);
            },
            routes: [
              GoRoute(
                path: 'add-reminder',
                name: 'addReminder',
                builder: (context, state) {
                  final dependentId = state.pathParameters['dependentId']!;
                  return AddReminderScreen(dependentId: dependentId);
                },
              ),
              GoRoute(
                path: 'emergency-contacts',
                name: 'emergencyContacts',
                builder: (context, state) {
                  final dependentId = state.pathParameters['dependentId']!;
                  return EmergencyContactsScreen(dependentId: dependentId);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'reminder/:reminderId/edit',
            name: 'editReminder',
            builder: (context, state) {
              final reminderId = state.pathParameters['reminderId']!;
              return EditReminderScreen(reminderId: reminderId);
            },
          ),
        ],
      ),

      // Dependent routes
      GoRoute(
        path: AppRoutes.dependentHome,
        name: 'dependentHome',
        builder: (context, state) => const DependentHomeScreen(),
        routes: [
          GoRoute(
            path: 'reminder/:instanceId',
            name: 'reminderAlert',
            builder: (context, state) {
              final instanceId = state.pathParameters['instanceId']!;
              return ReminderAlertScreen(instanceId: instanceId);
            },
          ),
          GoRoute(
            path: 'sos',
            name: 'sos',
            builder: (context, state) => const SosScreen(),
          ),
        ],
      ),

      // Settings
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'timezone',
            name: 'timezoneSettings',
            builder: (context, state) => const TimezoneSettingsScreen(),
          ),
          GoRoute(
            path: 'edit-profile',
            name: 'editProfile',
            builder: (context, state) => const EditProfileScreen(),
          ),
          GoRoute(
            path: 'linked-user',
            name: 'linkedUserDetail',
            builder: (context, state) {
              final userData = state.extra as LinkedUserData;
              return LinkedUserDetailScreen(userData: userData);
            },
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => _ErrorScreen(error: state.error),
  );

  String _getInitialLocation() {
    if (!isOnboardingComplete) {
      return AppRoutes.welcome;
    }

    if (userRole == 'caregiver') {
      return AppRoutes.caregiverHome;
    } else if (userRole == 'dependent') {
      return AppRoutes.dependentHome;
    }

    return AppRoutes.welcome;
  }
}

class _ErrorScreen extends StatelessWidget {
  final Exception? error;

  const _ErrorScreen({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.welcome),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Extension for easy navigation
extension GoRouterExtension on BuildContext {
  void goToDependentDashboard(String dependentId) {
    go('/caregiver/dependent/$dependentId');
  }

  /// Navigate to add reminder and return true if a reminder was created
  Future<bool?> goToAddReminder(String dependentId) {
    return push<bool>('/caregiver/dependent/$dependentId/add-reminder');
  }

  /// Navigate to edit reminder and return true if the reminder was modified
  Future<bool?> goToEditReminder(String reminderId) {
    return push<bool>('/caregiver/reminder/$reminderId/edit');
  }

  void goToEmergencyContacts(String dependentId) {
    go('/caregiver/dependent/$dependentId/emergency-contacts');
  }

  void goToReminderAlert(String instanceId) {
    go('/dependent/reminder/$instanceId');
  }
}
