using System.ComponentModel.DataAnnotations;

namespace ParentalCareApi.DTOs;

public record UserDto(
    string Id,
    string FirstName,
    string? LastName,
    string Email,
    string Role,
    string? PhoneNumber,
    string UniqueCode,
    string? AvatarUrl,
    bool EmailVerified,
    string Timezone,
    DateTime CreatedAt,
    DateTime? LastLoginAt
);

public record UpdateUserRequest(
    string? FirstName,
    string? LastName,
    string? PhoneNumber,
    string? AvatarUrl,
    string? Timezone
);

public record UpdateDeviceTokenRequest(
    [Required] string DeviceToken
);

public record UpdateLinkedUserRequest(
    string? FirstName,
    string? LastName
);

public record UserSearchResult(
    string Id,
    string FirstName,
    string? LastName,
    string Role,
    string UniqueCode,
    string? AvatarUrl,
    string? Email,
    string? PhoneNumber
);
