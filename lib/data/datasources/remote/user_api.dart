import 'api_client.dart';
import 'auth_api.dart';

/// User search result data
class UserSearchResult {
  final String id;
  final String name;
  final String role;
  final String uniqueCode;
  final String? avatarUrl;
  final String? email;
  final String? phoneNumber;

  UserSearchResult({
    required this.id,
    required this.name,
    required this.role,
    required this.uniqueCode,
    this.avatarUrl,
    this.email,
    this.phoneNumber,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      uniqueCode: json['uniqueCode'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'uniqueCode': uniqueCode,
        'avatarUrl': avatarUrl,
        'email': email,
        'phoneNumber': phoneNumber,
      };
}

/// User API service
class UserApi {
  final ApiClient _client;

  UserApi(this._client);

  /// Get current user profile
  Future<UserData> getCurrentUser() async {
    final response = await _client.get('/api/users/me');
    return UserData.fromJson(response);
  }

  /// Update current user profile
  Future<UserData> updateCurrentUser({
    String? name,
    String? phoneNumber,
    String? avatarUrl,
  }) async {
    final response = await _client.put(
      '/api/users/me',
      body: {
        if (name != null) 'name': name,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      },
    );
    return UserData.fromJson(response);
  }

  /// Find user by unique code
  Future<UserSearchResult> findByUniqueCode(String code) async {
    final response = await _client.get('/api/users/code/$code');
    return UserSearchResult.fromJson(response);
  }

  /// Find user by email
  Future<UserSearchResult> findByEmail(String email) async {
    final response = await _client.get('/api/users/email/$email');
    return UserSearchResult.fromJson(response);
  }

  /// Get user by ID
  Future<UserSearchResult> getById(String id) async {
    final response = await _client.get('/api/users/$id');
    return UserSearchResult.fromJson(response);
  }

  /// Update device token for push notifications (legacy endpoint)
  Future<void> updateDeviceToken(String deviceToken) async {
    await _client.put(
      '/api/users/device-token',
      body: {'deviceToken': deviceToken},
    );
  }

  /// Register device token for push notifications (multi-device support)
  Future<void> registerDeviceToken({
    required String token,
    required String platform,
    String? tokenType,
    String? deviceName,
    String? appVersion,
  }) async {
    await _client.post(
      '/api/device-tokens',
      body: {
        'token': token,
        'platform': platform,
        if (tokenType != null) 'tokenType': tokenType,
        if (deviceName != null) 'deviceName': deviceName,
        if (appVersion != null) 'appVersion': appVersion,
      },
    );
  }

  /// Invalidate device token (e.g., on logout)
  Future<void> invalidateDeviceToken(String token) async {
    await _client.post(
      '/api/device-tokens/invalidate',
      body: {'token': token},
    );
  }

  /// Logout device - invalidate token and clear session
  Future<void> logoutDevice(String token) async {
    await _client.post(
      '/api/device-tokens/logout',
      body: {'token': token},
    );
  }

  /// Update user timezone
  Future<UserData> updateTimezone(String timezone) async {
    final response = await _client.put(
      '/api/users/me',
      body: {'timezone': timezone},
    );
    return UserData.fromJson(response);
  }

  /// Update a linked user's name (caregiver updating dependent)
  Future<UserSearchResult> updateLinkedUserName(String userId, String name) async {
    final response = await _client.put(
      '/api/users/$userId',
      body: {'name': name},
    );
    return UserSearchResult.fromJson(response);
  }
}
