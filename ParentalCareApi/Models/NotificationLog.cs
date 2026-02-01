using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ParentalCareApi.Models;

public class NotificationLog
{
    [Key]
    [StringLength(36)]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [Required]
    [StringLength(36)]
    public string UserId { get; set; } = string.Empty;

    [StringLength(36)]
    public string? DeviceTokenId { get; set; }

    [Required]
    [StringLength(50)]
    public string Type { get; set; } = string.Empty; // "reminder", "escalation", "sos"

    [StringLength(36)]
    public string? ReferenceId { get; set; } // instanceId or sosEventId

    [StringLength(200)]
    public string? Title { get; set; }

    [StringLength(500)]
    public string? Body { get; set; }

    public string? Payload { get; set; } // JSON data payload

    public DateTime? ScheduledAt { get; set; }

    public DateTime? SentAt { get; set; }

    public DateTime? DeliveredAt { get; set; } // From FCM delivery receipt

    public DateTime? ReadAt { get; set; } // When user opened notification

    [Required]
    [StringLength(20)]
    public string Status { get; set; } = "scheduled"; // "scheduled", "sent", "delivered", "failed", "cancelled"

    [StringLength(500)]
    public string? ErrorMessage { get; set; }

    public int RetryCount { get; set; } = 0;

    [StringLength(100)]
    public string? FcmMessageId { get; set; } // FCM response message ID

    public int EscalationLevel { get; set; } = 0;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    [ForeignKey("UserId")]
    public User User { get; set; } = null!;

    [ForeignKey("DeviceTokenId")]
    public UserDeviceToken? DeviceToken { get; set; }
}

public enum NotificationStatus
{
    Scheduled,
    Sent,
    Delivered,
    Failed,
    Cancelled,
    Expired
}

public enum NotificationType
{
    Reminder,
    Escalation,
    Sos,
    System
}
