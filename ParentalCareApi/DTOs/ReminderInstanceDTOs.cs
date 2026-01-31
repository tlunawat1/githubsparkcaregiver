using System.ComponentModel.DataAnnotations;

namespace ParentalCareApi.DTOs;

public record ReminderInstanceDto(
    string Id,
    string ReminderId,
    DateTime ScheduledTime,
    string Status,
    DateTime? CompletedAt,
    DateTime? SnoozedUntil,
    int EscalationLevel,
    DateTime CreatedAt,
    // Include reminder details for convenience
    string? ReminderTitle,
    string? ReminderDescription,
    string? VoiceNoteUrl,
    string? Priority
);

public record CreateInstanceRequest(
    [Required] string ReminderId,
    [Required] DateTime ScheduledTime
);

public record SnoozeInstanceRequest(
    [Required] DateTime SnoozedUntil
);
