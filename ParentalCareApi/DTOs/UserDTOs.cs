using System.ComponentModel.DataAnnotations;

namespace ParentalCareApi.DTOs;

public record UserDto(
    string Id,
    string Name,
    string Email,
    string Role,
    string? PhoneNumber,
    string UniqueCode,
    string? AvatarUrl,
    bool EmailVerified,
    DateTime CreatedAt,
    DateTime? LastLoginAt
);

public record UpdateUserRequest(
    string? Name,
    string? PhoneNumber,
    string? AvatarUrl
);

public record UpdateDeviceTokenRequest(
    [Required] string DeviceToken
);

public record UserSearchResult(
    string Id,
    string Name,
    string Role,
    string UniqueCode,
    string? AvatarUrl
);
