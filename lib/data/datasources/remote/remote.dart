/// Remote data sources for Azure backend communication
///
/// This library provides API clients for communicating with the Azure backend:
/// - [ApiClient] - HTTP client with authentication handling
/// - [AuthApi] - Authentication endpoints (register, login, verify)
/// - [UserApi] - User profile and search endpoints
/// - [RelationshipApi] - Caregiver-dependent relationship management
/// - [ReminderApi] - Reminder CRUD operations
/// - [SosApi] - SOS alert management
/// - [SignalRService] - Real-time communication via SignalR
/// - [SyncManager] - Offline-first sync management

export 'api_client.dart';
export 'auth_api.dart';
export 'user_api.dart';
export 'relationship_api.dart';
export 'reminder_api.dart';
export 'sos_api.dart';
export 'signalr_service.dart';
export 'sync_manager.dart';
