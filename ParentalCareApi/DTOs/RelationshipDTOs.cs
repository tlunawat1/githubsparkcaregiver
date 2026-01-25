using System.ComponentModel.DataAnnotations;

namespace ParentalCareApi.DTOs;

public record RelationshipDto(
    string Id,
    string CaregiverId,
    string DependentId,
    string Status,
    string? LinkingCode,
    DateTime? CodeExpiresAt,
    string InitiatedBy,
    DateTime CreatedAt,
    DateTime? VerifiedAt,
    UserSearchResult? Caregiver,
    UserSearchResult? Dependent
);

public record CreateRelationshipRequest(
    [Required] string TargetUserIdentifier, // Can be UniqueCode or Email
    [Required] string InitiatedBy // "caregiver" or "dependent"
);

public record CreateRelationshipResponse(
    string Id,
    string Status,
    string? LinkingCode,
    DateTime? CodeExpiresAt,
    string Message
);

public record VerifyLinkingCodeRequest(
    [Required][StringLength(5)] string Code
);

public record VerifyLinkingCodeResponse(
    bool Success,
    string Message,
    RelationshipDto? Relationship
);

public record PendingLinkDto(
    string RelationshipId,
    string CaregiverId,
    string CaregiverName,
    string? CaregiverAvatarUrl,
    string Status,
    DateTime CreatedAt
);
