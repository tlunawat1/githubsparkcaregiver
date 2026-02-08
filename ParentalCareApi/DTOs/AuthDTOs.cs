using System.ComponentModel.DataAnnotations;

namespace ParentalCareApi.DTOs;

// Registration
public record RegisterRequest(
    [Required][StringLength(100)] string FirstName,
    [StringLength(100)] string? LastName,
    [Required][EmailAddress] string Email,
    [Required][MinLength(6)] string Password,
    [Required] string Role, // "caregiver" or "dependent"
    string? PhoneNumber,
    string? Timezone // IANA format, e.g., "America/New_York"
);

public record RegisterResponse(
    string Id,
    string FirstName,
    string? LastName,
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

public record SendVerificationCodeResponse(
    bool Success,
    string Message
);
