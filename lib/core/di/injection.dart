import 'package:get_it/get_it.dart';
import '../../data/datasources/local/database.dart';
import '../../data/repositories/repositories.dart';

/// Global service locator instance
final getIt = GetIt.instance;

/// Initialize all dependencies
Future<void> configureDependencies() async {
  // Database
  getIt.registerSingleton<AppDatabase>(AppDatabase());

  // Repositories
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
