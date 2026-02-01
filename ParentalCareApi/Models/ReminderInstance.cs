using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ParentalCareApi.Models;

public class ReminderInstance
{
    [Key]
    [StringLength(36)]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [Required]
    [StringLength(36)]
    public string ReminderId { get; set; } = string.Empty;

    [Required]
    public DateTime ScheduledTime { get; set; }

    [Required]
    [StringLength(20)]
    public string Status { get; set; } = "pending"; // "pending", "completed", "missed", "snoozed"

    public DateTime? CompletedAt { get; set; }

    public DateTime? SnoozedUntil { get; set; }

    [Required]
    public int EscalationLevel { get; set; } = 0; // 0, 1, 2

    public string? NotificationJobIds { get; set; } // JSON array of Hangfire job IDs for cancellation

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Navigation property
    [ForeignKey("ReminderId")]
    public Reminder Reminder { get; set; } = null!;
}
