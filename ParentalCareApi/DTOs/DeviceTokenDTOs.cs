using System.ComponentModel.DataAnnotations;

namespace ParentalCareApi.DTOs;

public record RegisterDeviceTokenRequest(
    [Required] string Token,
    [Required] string Platform, // "iOS" or "Android"
    string? TokenType, // "fcm" or "voip"
    string? DeviceName,
    string? AppVersion
);

public record DeviceTokenDto(
    string Id,
    string Token,
    string Platform,
    string TokenType,
    string? DeviceName,
    string? AppVersion,
    bool IsValid,
    DateTime? LastUsedAt,
    DateTime CreatedAt
);

public record InvalidateDeviceTokenRequest(
    [Required] string Token
);
