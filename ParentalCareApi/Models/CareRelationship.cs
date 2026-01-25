using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ParentalCareApi.Models;

public class CareRelationship
{
    [Key]
    [StringLength(36)]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [Required]
    [StringLength(36)]
    public string CaregiverId { get; set; } = string.Empty;

    [Required]
    [StringLength(36)]
    public string DependentId { get; set; } = string.Empty;

    [Required]
    [StringLength(20)]
    public string Status { get; set; } = "pending"; // "pending", "active", "removed"

    [StringLength(5)]
    public string? LinkingCode { get; set; }

    public DateTime? CodeExpiresAt { get; set; }

    public int VerificationAttempts { get; set; } = 0;

    [Required]
    [StringLength(20)]
    public string InitiatedBy { get; set; } = string.Empty; // "caregiver" or "dependent"

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public DateTime? VerifiedAt { get; set; }

    // Navigation properties
    [ForeignKey("CaregiverId")]
    public User Caregiver { get; set; } = null!;

    [ForeignKey("DependentId")]
    public User Dependent { get; set; } = null!;
}
