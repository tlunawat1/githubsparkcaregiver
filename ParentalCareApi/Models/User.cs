using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ParentalCareApi.Models;

public class User
{
    [Key]
    [StringLength(36)]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [Required]
    [StringLength(200)]
    public string Name { get; set; } = string.Empty;

    [Required]
    [StringLength(255)]
    public string Email { get; set; } = string.Empty;

    [Required]
    [StringLength(255)]
    public string PasswordHash { get; set; } = string.Empty;

    [Required]
    [StringLength(20)]
    public string Role { get; set; } = string.Empty; // "caregiver" or "dependent"

    [StringLength(20)]
    public string? PhoneNumber { get; set; }

    [Required]
    [StringLength(9)]
    public string UniqueCode { get; set; } = string.Empty;

    [StringLength(500)]
    public string? AvatarUrl { get; set; }

    public bool EmailVerified { get; set; } = false;

    [StringLength(6)]
    public string? VerificationCode { get; set; }

    public DateTime? VerificationCodeExpiry { get; set; }
    public DateTime? VerificationCodeSentAt { get; set; }

    [StringLength(255)]
    public string? PasswordResetCodeHash { get; set; }

    public DateTime? PasswordResetCodeExpiry { get; set; }
    public DateTime? PasswordResetCodeSentAt { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public DateTime? LastLoginAt { get; set; }

    [StringLength(500)]
    public string? DeviceToken { get; set; } // For push notifications (legacy - use UserDeviceTokens)

    [StringLength(500)]
    public string? RefreshToken { get; set; }

    public DateTime? RefreshTokenExpiry { get; set; }

    [StringLength(50)]
    public string Timezone { get; set; } = "UTC"; // IANA timezone (e.g., "America/New_York")

    // Navigation properties
    [InverseProperty("Caregiver")]
    public ICollection<CareRelationship> CaregiverRelationships { get; set; } = new List<CareRelationship>();

    [InverseProperty("Dependent")]
    public ICollection<CareRelationship> DependentRelationships { get; set; } = new List<CareRelationship>();

    public ICollection<Reminder> CreatedReminders { get; set; } = new List<Reminder>();
    public ICollection<Reminder> AssignedReminders { get; set; } = new List<Reminder>();
    public ICollection<SosEvent> SosEvents { get; set; } = new List<SosEvent>();
    public ICollection<UserDeviceToken> DeviceTokens { get; set; } = new List<UserDeviceToken>();
}
