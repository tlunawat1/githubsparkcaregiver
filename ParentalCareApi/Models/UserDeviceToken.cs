using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ParentalCareApi.Models;

public class UserDeviceToken
{
    [Key]
    [StringLength(36)]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [Required]
    [StringLength(36)]
    public string UserId { get; set; } = string.Empty;

    [Required]
    [StringLength(500)]
    public string Token { get; set; } = string.Empty;

    [Required]
    [StringLength(20)]
    public string Platform { get; set; } = string.Empty; // "iOS", "Android"

    [Required]
    [StringLength(20)]
    public string TokenType { get; set; } = "fcm"; // "fcm" or "voip"

    [StringLength(100)]
    public string? DeviceName { get; set; }

    [StringLength(20)]
    public string? AppVersion { get; set; }

    public bool IsValid { get; set; } = true;

    public DateTime? LastUsedAt { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    // Navigation property
    [ForeignKey("UserId")]
    public User User { get; set; } = null!;
}
