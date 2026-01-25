using System.ComponentModel.DataAnnotations;

namespace ParentalCareApi.DTOs;

public record ReminderDto(
    string Id,
    string CreatorId,
    string DependentId,
    string Title,
    string? Description,
    string? VoiceNoteUrl,
    string RepeatPattern,
    string? RepeatDays,
    int Hour,
    int Minute,
    string Priority,
    bool IsActive,
    DateTime StartDate,
    DateTime? EndDate,
    DateTime CreatedAt,
    DateTime UpdatedAt,
    string? CreatorName,
    string? DependentName
);

public record CreateReminderRequest(
    [Required] string DependentId,
    [Required][StringLength(200)] string Title,
    string? Description,
    string? VoiceNoteUrl,
    [Required] string RepeatPattern, // "once", "daily", "weekly", "specific_days"
    string? RepeatDays, // JSON array like "[1,3,5]"
    [Required][Range(0, 23)] int Hour,
    [Required][Range(0, 59)] int Minute,
    string Priority = "normal", // "normal", "high"
    DateTime? StartDate = null,
    DateTime? EndDate = null
);

public record UpdateReminderRequest(
    string? Title,
    string? Description,
    string? VoiceNoteUrl,
    string? RepeatPattern,
    string? RepeatDays,
    int? Hour,
    int? Minute,
    string? Priority,
    bool? IsActive,
    DateTime? StartDate,
    DateTime? EndDate
);
