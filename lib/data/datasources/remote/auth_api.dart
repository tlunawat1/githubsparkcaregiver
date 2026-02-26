import 'api_client.dart';

/// Data class for user data from API
class UserData {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? phoneNumber;
  final String uniqueCode;
  final String? avatarUrl;
  final bool emailVerified;
  final String timezone;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  UserData({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phoneNumber,
    required this.uniqueCode,
    this.avatarUrl,
    required this.emailVerified,
    required this.timezone,
    required this.createdAt,
    this.lastLoginAt,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      uniqueCode: json['uniqueCode'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      emailVerified: json['emailVerified'] as bool? ?? false,
      timezone: json['timezone'] as String? ?? 'UTC',
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'phoneNumber': phoneNumber,
        'uniqueCode': uniqueCode,
        'avatarUrl': avatarUrl,
        'emailVerified': emailVerified,
        'timezone': timezone,
        'createdAt': createdAt.toIso8601String(),
        'lastLoginAt': lastLoginAt?.toIso8601String(),
      };
}

/// Response from login/register
class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final UserData user;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      user: UserData.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

/// Response from registration
class RegisterResponse {
  final String id;
  final String name;
  final String email;
  final String role;
  final String uniqueCode;
  final bool emailVerified;
  final String message;

  RegisterResponse({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.uniqueCode,
    required this.emailVerified,
    required this.message,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      uniqueCode: json['uniqueCode'] as String,
      emailVerified: json['emailVerified'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }
}

/// Response from login that may require verification
class LoginResponse {
  final bool requiresVerification;
  final String? userId;
  final String? message;
  final AuthResponse? authResponse;

  LoginResponse({
    this.requiresVerification = false,
    this.userId,
    this.message,
    this.authResponse,
  });

  String? get accessToken => authResponse?.accessToken;
  String? get refreshToken => authResponse?.refreshToken;
  UserData? get user => authResponse?.user;
  String? get role => authResponse?.user.role;
}

/// Response from email verification
class VerifyEmailResponse {
  final String message;
  final String uniqueCode;

  VerifyEmailResponse({
    required this.message,
    required this.uniqueCode,
  });

  factory VerifyEmailResponse.fromJson(Map<String, dynamic> json) {
    return VerifyEmailResponse(
      message: json['message'] as String? ?? '',
      uniqueCode: json['uniqueCode'] as String? ?? '',
    );
  }
}

class SendVerificationCodeResponse {
  final bool success;
  final String message;
  final int? retryAfterSeconds;
  final DateTime? codeExpiresAt;

  SendVerificationCodeResponse({
    required this.success,
    required this.message,
    this.retryAfterSeconds,
    this.codeExpiresAt,
  });

  factory SendVerificationCodeResponse.fromJson(Map<String, dynamic> json) {
    return SendVerificationCodeResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      retryAfterSeconds: json['retryAfterSeconds'] as int?,
      codeExpiresAt: json['codeExpiresAt'] != null
          ? DateTime.tryParse(json['codeExpiresAt'] as String)
          : null,
    );
  }
}

class ResetPasswordResponse {
  final bool success;
  final String message;

  ResetPasswordResponse({
    required this.success,
    required this.message,
  });

  factory ResetPasswordResponse.fromJson(Map<String, dynamic> json) {
    return ResetPasswordResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }
}

/// Authentication API service
class AuthApi {
  final ApiClient _client;

  AuthApi(this._client);

  /// Register a new user
  Future<RegisterResponse> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phoneNumber,
    String? timezone,
  }) async {
    final response = await _client.post(
      '/api/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (timezone != null) 'timezone': timezone,
      },
      requiresAuth: false,
    );

    return RegisterResponse.fromJson(response);
  }

  /// Login with email and password
  /// Returns LoginResponse which may indicate verification is required
  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      '/api/auth/login',
      body: {
        'email': email,
        'password': password,
      },
      requiresAuth: false,
    );

    // Check if verification is required
    if (response['requiresVerification'] == true) {
      return LoginResponse(
        requiresVerification: true,
        userId: response['userId'] as String?,
        message: response['message'] as String?,
      );
    }

    final authResponse = AuthResponse.fromJson(response);

    // Store tokens
    await _client.setTokens(
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
      expiry: authResponse.expiresAt,
    );

    return LoginResponse(authResponse: authResponse);
  }

  /// Login with email and verification code
  Future<LoginResponse> loginWithCode({
    required String email,
    required String code,
  }) async {
    final response = await _client.post(
      '/api/auth/login-code',
      body: {
        'email': email,
        'code': code,
      },
      requiresAuth: false,
    );

    // Check if verification is required
    if (response['requiresVerification'] == true) {
      return LoginResponse(
        requiresVerification: true,
        userId: response['userId'] as String?,
        message: response['message'] as String?,
      );
    }

    final authResponse = AuthResponse.fromJson(response);

    // Store tokens
    await _client.setTokens(
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
      expiry: authResponse.expiresAt,
    );

    return LoginResponse(authResponse: authResponse);
  }

  /// Verify email with code
  Future<VerifyEmailResponse> verifyEmail({
    required String userId,
    required String code,
  }) async {
    final response = await _client.post(
      '/api/auth/verify-email',
      body: {
        'userId': userId,
        'code': code,
      },
      requiresAuth: false,
    );

    return VerifyEmailResponse.fromJson(response);
  }

  /// Resend verification code to user
  Future<SendVerificationCodeResponse> resendVerificationCode({
    required String userId,
  }) async {
    final response = await _client.post(
      '/api/auth/resend-verification',
      body: {'userId': userId},
      requiresAuth: false,
    );

    return SendVerificationCodeResponse.fromJson(response);
  }

  /// Send verification code to email
  Future<SendVerificationCodeResponse> sendVerificationCode({
    required String email,
  }) async {
    final response = await _client.post(
      '/api/auth/send-verification-code',
      body: {'email': email},
      requiresAuth: false,
    );

    return SendVerificationCodeResponse.fromJson(response);
  }

  /// Request a password reset code to be emailed.
  /// Always returns success for non-existent emails (anti-enumeration).
  Future<SendVerificationCodeResponse> requestPasswordReset({
    required String email,
  }) async {
    final response = await _client.post(
      '/api/auth/request-password-reset',
      body: {'email': email},
      requiresAuth: false,
    );

    return SendVerificationCodeResponse.fromJson(response);
  }

  /// Reset password using emailed code.
  Future<ResetPasswordResponse> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await _client.post(
      '/api/auth/reset-password',
      body: {
        'email': email,
        'code': code,
        'newPassword': newPassword,
      },
      requiresAuth: false,
    );

    return ResetPasswordResponse.fromJson(response);
  }

  /// Refresh access token
  Future<AuthResponse> refreshToken({required String refreshToken}) async {
    final response = await _client.post(
      '/api/auth/refresh-token',
      body: {'refreshToken': refreshToken},
      requiresAuth: false,
    );

    final authResponse = AuthResponse.fromJson(response);

    // Store new tokens
    await _client.setTokens(
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
      expiry: authResponse.expiresAt,
    );

    return authResponse;
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _client.post('/api/auth/logout');
    } finally {
      await _client.clearTokens();
    }
  }
}
