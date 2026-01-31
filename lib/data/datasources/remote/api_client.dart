import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Exception for API errors
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? data;

  ApiException(this.statusCode, this.message, [this.data]);

  @override
  String toString() => 'ApiException: $statusCode - $message';

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isServerError => statusCode >= 500;
}

/// API client for communicating with the backend
class ApiClient {
  // Configuration
  static const String _defaultBaseUrl = 'https://remotecaregiver-api-gremgwfab5c9fbhs.canadacentral-01.azurewebsites.net';
  static const Duration _timeout = Duration(seconds: 30);

  final String baseUrl;
  final http.Client _httpClient;
  final FlutterSecureStorage _secureStorage;

  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;

  // Callbacks for token refresh
  Function(String accessToken, String refreshToken, DateTime expiry)?
      onTokensUpdated;
  Function()? onAuthenticationRequired;

  ApiClient({
    String? baseUrl,
    http.Client? httpClient,
    FlutterSecureStorage? secureStorage,
  })  : baseUrl = baseUrl ?? _defaultBaseUrl,
        _httpClient = httpClient ?? http.Client(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Initialize the client and load stored tokens
  Future<void> initialize() async {
    _accessToken = await _secureStorage.read(key: 'access_token');
    _refreshToken = await _secureStorage.read(key: 'refresh_token');

    final expiryStr = await _secureStorage.read(key: 'token_expiry');
    if (expiryStr != null) {
      _tokenExpiry = DateTime.tryParse(expiryStr);
    }
  }

  /// Check if user is authenticated
  bool get isAuthenticated =>
      _accessToken != null &&
      _tokenExpiry != null &&
      _tokenExpiry!.isAfter(DateTime.now());

  /// Get current access token (for SignalR)
  String? get accessToken => _accessToken;

  /// Set authentication tokens
  Future<void> setTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiry,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _tokenExpiry = expiry;

    await _secureStorage.write(key: 'access_token', value: accessToken);
    await _secureStorage.write(key: 'refresh_token', value: refreshToken);
    await _secureStorage.write(key: 'token_expiry', value: expiry.toIso8601String());

    onTokensUpdated?.call(accessToken, refreshToken, expiry);
  }

  /// Clear authentication tokens (logout)
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;

    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');
    await _secureStorage.delete(key: 'token_expiry');
  }

  /// Make a GET request
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParameters,
    bool requiresAuth = true,
  }) async {
    return _request(
      'GET',
      endpoint,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
  }

  /// Make a POST request
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    return _request(
      'POST',
      endpoint,
      body: body,
      requiresAuth: requiresAuth,
    );
  }

  /// Make a PUT request
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    return _request(
      'PUT',
      endpoint,
      body: body,
      requiresAuth: requiresAuth,
    );
  }

  /// Make a DELETE request
  Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool requiresAuth = true,
  }) async {
    return _request(
      'DELETE',
      endpoint,
      requiresAuth: requiresAuth,
    );
  }

  /// Upload a file using multipart form data
  Future<Map<String, dynamic>> uploadFile(
    String endpoint,
    String filePath,
    String fieldName, {
    bool requiresAuth = true,
  }) async {
    // Check token expiry and refresh if needed
    if (requiresAuth && _shouldRefreshToken()) {
      await _refreshAccessToken();
    }

    final uri = Uri.parse('$baseUrl$endpoint');

    try {
      final request = http.MultipartRequest('POST', uri);

      // Add authorization header
      if (requiresAuth && _accessToken != null) {
        request.headers['Authorization'] = 'Bearer $_accessToken';
      }

      // Add the file
      final file = await http.MultipartFile.fromPath(fieldName, filePath);
      request.files.add(file);

      // Send the request
      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response, requiresAuth);
    } on SocketException {
      throw ApiException(0, 'Network error. Please check your connection.');
    } on http.ClientException catch (e) {
      throw ApiException(0, 'Connection error: ${e.message}');
    }
  }

  /// Internal request method
  Future<Map<String, dynamic>> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
    bool requiresAuth = true,
  }) async {
    // Check token expiry and refresh if needed
    if (requiresAuth && _shouldRefreshToken()) {
      await _refreshAccessToken();
    }

    // Build URI
    var uri = Uri.parse('$baseUrl$endpoint');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParameters);
    }

    // Build headers
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }

    // Make request
    http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _httpClient
              .get(uri, headers: headers)
              .timeout(_timeout);
          break;
        case 'POST':
          response = await _httpClient
              .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
              .timeout(_timeout);
          break;
        case 'PUT':
          response = await _httpClient
              .put(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
              .timeout(_timeout);
          break;
        case 'DELETE':
          response = await _httpClient
              .delete(uri, headers: headers)
              .timeout(_timeout);
          break;
        default:
          throw ApiException(0, 'Unsupported HTTP method: $method');
      }
    } on SocketException {
      throw ApiException(0, 'Network error. Please check your connection.');
    } on http.ClientException catch (e) {
      throw ApiException(0, 'Connection error: ${e.message}');
    }

    // Handle response
    return _handleResponse(response, requiresAuth);
  }

  /// Handle API response
  Map<String, dynamic> _handleResponse(
      http.Response response, bool requiresAuth) {
    final statusCode = response.statusCode;

    // Parse response body
    Map<String, dynamic>? body;
    try {
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        } else if (decoded is List) {
          body = {'data': decoded};
        } else {
          body = {'data': decoded};
        }
      }
    } catch (_) {
      body = {'raw': response.body};
    }

    // Success
    if (statusCode >= 200 && statusCode < 300) {
      return body ?? {};
    }

    // Handle errors
    final message = body?['message'] as String? ??
        body?['error'] as String? ??
        'An error occurred';

    // Unauthorized - trigger re-authentication
    if (statusCode == 401 && requiresAuth) {
      onAuthenticationRequired?.call();
    }

    throw ApiException(statusCode, message, body);
  }

  /// Check if token should be refreshed
  bool _shouldRefreshToken() {
    if (_accessToken == null || _tokenExpiry == null) return false;

    // Refresh if token expires in less than 5 minutes
    final buffer = Duration(minutes: 5);
    return _tokenExpiry!.subtract(buffer).isBefore(DateTime.now());
  }

  /// Refresh the access token
  Future<void> _refreshAccessToken() async {
    if (_refreshToken == null) {
      onAuthenticationRequired?.call();
      throw ApiException(401, 'No refresh token available');
    }

    try {
      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl/api/auth/refresh-token'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'refreshToken': _refreshToken}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        await setTokens(
          accessToken: body['accessToken'] as String,
          refreshToken: body['refreshToken'] as String,
          expiry: DateTime.parse(body['expiresAt'] as String),
        );
      } else {
        // Refresh failed, require re-authentication
        await clearTokens();
        onAuthenticationRequired?.call();
        throw ApiException(401, 'Session expired. Please log in again.');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      await clearTokens();
      onAuthenticationRequired?.call();
      throw ApiException(401, 'Failed to refresh session');
    }
  }

  /// Dispose resources
  void dispose() {
    _httpClient.close();
  }
}
