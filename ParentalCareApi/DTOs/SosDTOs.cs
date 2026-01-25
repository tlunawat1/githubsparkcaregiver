namespace ParentalCareApi.DTOs;

public record SosEventDto(
    string Id,
    string DependentId,
    string Status,
    DateTime TriggeredAt,
    DateTime? ResolvedAt,
    string? ResolvedBy,
    string? Notes,
    DateTime CreatedAt,
    string? DependentName,
    string? ResolverName
);

public record TriggerSosRequest(
    string? Notes
);

public record TriggerSosResponse(
    string Id,
    string Status,
    DateTime TriggeredAt,
    string Message,
    int NotifiedCaregivers
);

public record ResolveSosRequest(
    string? Notes
);

public record ResolveSosResponse(
    bool Success,
    string Message,
    SosEventDto? Event
);
