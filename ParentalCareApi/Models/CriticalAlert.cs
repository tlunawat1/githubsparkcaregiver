using System.ComponentModel.DataAnnotations;

namespace ParentalCareApi.Models;

public class CriticalAlert
{
    [Key]
    [StringLength(36)]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [Required]
    [StringLength(50)]
    public string Type { get; set; } = string.Empty; // "sos_triggered", "reminder_urgent"

    [StringLength(36)]
    public string? ReferenceId { get; set; } // sosEventId or reminderInstanceId

    [StringLength(36)]
    public string? DependentId { get; set; }

    [StringLength(36)]
    public string? TargetUserId { get; set; } // caregiver receiving the alert

    [Required]
    [StringLength(20)]
    public string Status { get; set; } = "triggered"; // triggered, accepted, declined

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public DateTime? AcknowledgedAt { get; set; }

    [StringLength(36)]
    public string? AcknowledgedBy { get; set; }

    public string? Payload { get; set; }
}
