import 'api_client.dart';
import 'auth_api.dart';

/// User search result data
class UserSearchResult {
  final String id;
  final String name;
  final String role;
  final String uniqueCode;
  final String? avatarUrl;

  UserSearchResult({
    required this.id,
    required this.name,
    required this.role,
    required this.uniqueCode,
    this.avatarUrl,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      uniqueCode: json['uniqueCode'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'uniqueCode': uniqueCode,
        'avatarUrl': avatarUrl,
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

  /// Update device token for push notifications
  Future<void> updateDeviceToken(String deviceToken) async {
    await _client.put(
      '/api/users/device-token',
      body: {'deviceToken': deviceToken},
    );
  }
}
