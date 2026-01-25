/// API configuration constants
///
/// Update these values before deploying to production

class ApiConstants {
  ApiConstants._();

  /// Base URL for the REST API
  /// Development: Use localhost or ngrok URL
  /// Production: Use Azure App Service URL
  static const String baseUrl = 'https://remotecaregiver-api-gremgwfab5c9fbhs.canadacentral-01.azurewebsites.net';

  /// SignalR Hub URL for real-time communication
  static const String signalRHubUrl = '$baseUrl/hubs/sync';

  /// API version
  static const String apiVersion = 'v1';

  /// Request timeout in seconds
  static const int requestTimeoutSeconds = 30;

  /// Token refresh buffer in minutes
  /// Refresh token this many minutes before expiry
  static const int tokenRefreshBufferMinutes = 5;

  /// Maximum retry attempts for failed operations
  static const int maxRetryAttempts = 3;

  /// SignalR reconnect delay in seconds
  static const int signalRReconnectDelaySeconds = 5;

  /// Maximum SignalR reconnect attempts
  static const int maxSignalRReconnectAttempts = 10;

  /// Sync check interval in minutes
  static const int syncCheckIntervalMinutes = 5;

  /// API endpoints
  static const String authEndpoint = '/api/auth';
  static const String usersEndpoint = '/api/users';
  static const String relationshipsEndpoint = '/api/relationships';
  static const String remindersEndpoint = '/api/reminders';
  static const String sosEndpoint = '/api/sos';
}

/// Environment-specific configuration
enum ApiEnvironment {
  development,
  staging,
  production,
}

/// Get base URL for specific environment
String getBaseUrlForEnvironment(ApiEnvironment env) {
  switch (env) {
    case ApiEnvironment.development:
      return 'http://localhost:5000';
    case ApiEnvironment.staging:
      return 'https://remotecaregiver-staging.azurewebsites.net';
    case ApiEnvironment.production:
      return 'https://remotecaregiver-api-gremgwfab5c9fbhs.canadacentral-01.azurewebsites.net';
  }
}
