using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ParentalCareApi.Models;

public class SosEvent
{
    [Key]
    [StringLength(36)]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [Required]
    [StringLength(36)]
    public string DependentId { get; set; } = string.Empty;

    [Required]
    [StringLength(20)]
    public string Status { get; set; } = "triggered"; // "triggered", "cancelled", "resolved"

    public DateTime TriggeredAt { get; set; } = DateTime.UtcNow;

    public DateTime? ResolvedAt { get; set; }

    [StringLength(36)]
    public string? ResolvedBy { get; set; }

    public string? Notes { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    [ForeignKey("DependentId")]
    public User Dependent { get; set; } = null!;

    [ForeignKey("ResolvedBy")]
    public User? Resolver { get; set; }
}
