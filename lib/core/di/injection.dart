import 'package:get_it/get_it.dart';
import '../../data/datasources/local/database.dart';
import '../../data/datasources/remote/remote.dart';
import '../../data/repositories/repositories.dart';

/// Global service locator instance
final getIt = GetIt.instance;

/// Initialize all dependencies
Future<void> configureDependencies() async {
  // Database (Local)
  getIt.registerSingleton<AppDatabase>(AppDatabase());

  // Remote API Client
  final apiClient = ApiClient();
  await apiClient.initialize();
  getIt.registerSingleton<ApiClient>(apiClient);

  // Remote API Services
  getIt.registerLazySingleton<AuthApi>(
    () => AuthApi(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<UserApi>(
    () => UserApi(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<RelationshipApi>(
    () => RelationshipApi(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<ReminderApi>(
    () => ReminderApi(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<SosApi>(
    () => SosApi(getIt<ApiClient>()),
  );

  // SignalR Service
  getIt.registerLazySingleton<SignalRService>(
    () => SignalRService(),
  );

  // Sync Manager
  getIt.registerLazySingleton<SyncManager>(
    () => SyncManager(
      apiClient: getIt<ApiClient>(),
      authApi: getIt<AuthApi>(),
      userApi: getIt<UserApi>(),
      relationshipApi: getIt<RelationshipApi>(),
      reminderApi: getIt<ReminderApi>(),
      sosApi: getIt<SosApi>(),
      signalRService: getIt<SignalRService>(),
    ),
  );

  // Local Repositories
  getIt.registerLazySingleton<UserRepository>(
    () => UserRepository(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<ReminderRepository>(
    () => ReminderRepository(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<SosRepository>(
    () => SosRepository(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<EmergencyContactRepository>(
    () => EmergencyContactRepository(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<SettingsRepository>(
    () => SettingsRepository(getIt<AppDatabase>()),
  );

  getIt.registerLazySingleton<CareRelationshipRepository>(
    () => CareRelationshipRepository(getIt<AppDatabase>()),
  );
}

/// Reset all dependencies (useful for testing)
Future<void> resetDependencies() async {
  await getIt.reset();
}
