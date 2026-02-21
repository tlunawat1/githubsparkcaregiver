using System.ComponentModel.DataAnnotations;

namespace ParentalCareApi.DTOs;

// Registration
public record RegisterRequest(
    [Required][StringLength(200)] string Name,
    [Required][EmailAddress] string Email,
    [Required][MinLength(6)] string Password,
    [Required] string Role, // "caregiver" or "dependent"
    string? PhoneNumber,
    string? Timezone // IANA format, e.g., "America/New_York"
);

public record RegisterResponse(
    string Id,
    string Name,
    string Email,
    string Role,
    string UniqueCode,
    bool EmailVerified,
    string Message
);

// Login
public record LoginRequest(
    [Required][EmailAddress] string Email,
    [Required] string Password
);

public record LoginCodeRequest(
    [Required][EmailAddress] string Email,
    [Required][StringLength(6)] string Code
);

public record LoginResponse(
    string AccessToken,
    string RefreshToken,
    DateTime ExpiresAt,
    UserDto User
);

// Email verification
public record VerifyEmailRequest(
    [Required] string UserId,
    [Required][StringLength(6)] string Code
);

public record VerifyEmailResponse(
    bool Success,
    string Message,
    string? UniqueCode = null
);

// Refresh token
public record RefreshTokenRequest(
    [Required] string RefreshToken
);

// Send verification code
public record SendVerificationCodeRequest(
    [Required][EmailAddress] string Email
);

public record ResendVerificationRequest(
    [Required] string UserId
);

public record SendVerificationCodeResponse(
    bool Success,
    string Message,
    int? RetryAfterSeconds = null,
    DateTime? CodeExpiresAt = null
);

// Password reset
public record RequestPasswordResetRequest(
    [Required][EmailAddress] string Email
);

public record ResetPasswordRequest(
    [Required][EmailAddress] string Email,
    [Required][StringLength(6)] string Code,
    [Required][MinLength(6)] string NewPassword
);

public record ResetPasswordResponse(
    bool Success,
    string Message
);
